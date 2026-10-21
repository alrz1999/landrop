package dev.landrop.landrop

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.net.wifi.WpsInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Wi-Fi Direct (Wi-Fi P2P) assist. It only forms the group; once it exists both
 * devices share a normal IP link and Dart runs LanDrop discovery over it.
 * Dart asks for the runtime permission first (wifi_direct_service.dart).
 * Every method and callback runs on the main thread; all state lives here.
 */
class WifiDirectManager(context: Context) {
    private val app = context.applicationContext
    private val p2p = app.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private var channel: WifiP2pManager.Channel? = null
    private var receiver: BroadcastReceiver? = null

    /** Set by the EventChannel stream handler (MainActivity). */
    var sink: EventChannel.EventSink? = null

    /** {feature, wifiEnabled, supported}. */
    fun supported(): Map<String, Any?> {
        val feature = app.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT) &&
            p2p != null
        val wifi = app.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val enabled = try {
            wifi?.isWifiEnabled == true
        } catch (e: Exception) {
            false
        }
        return mapOf("feature" to feature, "wifiEnabled" to enabled, "supported" to (feature && enabled))
    }

    fun discover(result: MethodChannel.Result) {
        val (m, ch) = ready() ?: return unsupported(result)
        try {
            m.discoverPeers(ch, replyListener(result))
        } catch (e: SecurityException) {
            result.error("permission", e.message ?: "permission missing", null)
        }
    }

    fun stopDiscover(result: MethodChannel.Result) {
        val m = p2p
        val ch = channel
        if (m == null || ch == null) {
            result.success(true)
            return
        }
        try {
            m.stopPeerDiscovery(ch, replyListener(result))
        } catch (e: SecurityException) {
            result.error("permission", e.message ?: "permission missing", null)
        }
    }

    /** Invites [address]; the other device shows the system invitation dialog. */
    fun connect(address: String, groupOwnerIntent: Int?, result: MethodChannel.Result) {
        val (m, ch) = ready() ?: return unsupported(result)
        val config = WifiP2pConfig()
        config.deviceAddress = address
        config.wps.setup = WpsInfo.PBC
        if (groupOwnerIntent != null && groupOwnerIntent in 0..15) {
            config.groupOwnerIntent = groupOwnerIntent
        }
        try {
            m.connect(ch, config, replyListener(result))
        } catch (e: SecurityException) {
            result.error("permission", e.message ?: "permission missing", null)
        }
    }

    fun createGroup(result: MethodChannel.Result) {
        val (m, ch) = ready() ?: return unsupported(result)
        try {
            m.createGroup(ch, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    result.success(true)
                    refreshState()
                }

                override fun onFailure(reason: Int) {
                    if (reason == WifiP2pManager.BUSY) {
                        // A group may already exist: report it instead of failing.
                        refreshState()
                    }
                    result.error(codeFor(reason), messageFor(reason), null)
                }
            })
        } catch (e: SecurityException) {
            result.error("permission", e.message ?: "permission missing", null)
        }
    }

    /** Current connection state map (same shape as the "state" event). */
    fun info(result: MethodChannel.Result) {
        queryState { result.success(it) }
    }

    /** Stops discovery, cancels a pending invitation, removes the group, releases everything. */
    fun disconnect() {
        val m = p2p
        val ch = channel
        if (m != null && ch != null) {
            val ignore = object : WifiP2pManager.ActionListener {
                override fun onSuccess() {}
                override fun onFailure(reason: Int) {}
            }
            try {
                m.stopPeerDiscovery(ch, ignore)
                m.cancelConnect(ch, ignore)
                m.removeGroup(ch, ignore)
            } catch (e: SecurityException) {
                // Nothing to release without the permission.
            } catch (e: Exception) {
                // Best effort.
            }
        }
        release()
        emit(stateMap(false, false, null, null))
    }

    /** Unregisters the receiver and closes the channel (also from MainActivity.onDestroy). */
    fun release() {
        val r = receiver
        receiver = null
        if (r != null) {
            try {
                app.unregisterReceiver(r)
            } catch (e: IllegalArgumentException) {
                // Already unregistered.
            }
        }
        val ch = channel
        channel = null
        if (ch != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            try {
                ch.close()
            } catch (e: Exception) {
                // Best effort.
            }
        }
    }

    /** Releases everything and drops the event sink. */
    fun destroy() {
        disconnect()
        sink = null
    }

    // ---- internals ----

    private fun ready(): Pair<WifiP2pManager, WifiP2pManager.Channel>? {
        val m = p2p ?: return null
        var ch = channel
        if (ch == null) {
            ch = m.initialize(app, Looper.getMainLooper()) {
                // Framework lost the channel; start over on the next call.
                channel = null
            }
            channel = ch
        }
        if (ch == null) return null
        registerReceiverOnce()
        return Pair(m, ch)
    }

    private fun registerReceiverOnce() {
        if (receiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                val i = intent ?: return
                when (i.action) {
                    WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                        val state = i.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                        if (state != WifiP2pManager.WIFI_P2P_STATE_ENABLED) {
                            emitError(WifiP2pManager.P2P_UNSUPPORTED)
                        }
                    }
                    WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> requestPeers()
                    WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> refreshState()
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            app.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            app.registerReceiver(r, filter)
        }
        receiver = r
    }

    private fun requestPeers() {
        val m = p2p ?: return
        val ch = channel ?: return
        try {
            m.requestPeers(ch) { list ->
                val peers = list.deviceList.map { d ->
                    mapOf(
                        "name" to (d.deviceName ?: ""),
                        "address" to (d.deviceAddress ?: ""),
                        "status" to statusName(d.status),
                    )
                }
                emit(mapOf("type" to "peers", "peers" to peers))
            }
        } catch (e: SecurityException) {
            emit(errorMap("permission", "Permission missing"))
        }
    }

    private fun refreshState() {
        queryState { emit(it) }
    }

    /** Connection info, plus group info (SSID) when a group exists. */
    private fun queryState(done: (Map<String, Any?>) -> Unit) {
        val m = p2p
        val ch = channel
        if (m == null || ch == null) {
            done(stateMap(false, false, null, null))
            return
        }
        try {
            m.requestConnectionInfo(ch) { info ->
                if (info == null || !info.groupFormed) {
                    done(stateMap(false, false, null, null))
                } else {
                    val owner = info.groupOwnerAddress?.hostAddress
                    val isOwner = info.isGroupOwner
                    try {
                        m.requestGroup(ch, isOwner, owner, done)
                    } catch (e: SecurityException) {
                        done(stateMap(true, isOwner, owner, null))
                    }
                }
            }
        } catch (e: SecurityException) {
            done(stateMap(false, false, null, null))
        }
    }

    private fun WifiP2pManager.requestGroup(
        ch: WifiP2pManager.Channel,
        isOwner: Boolean,
        owner: String?,
        done: (Map<String, Any?>) -> Unit,
    ) {
        requestGroupInfo(ch) { group ->
            val ssid = group?.networkName
            val state = stateMap(true, isOwner, owner, ssid).toMutableMap()
            if (isOwner && group != null) {
                state["passphrase"] = group.passphrase
                state["clients"] = group.clientList.map { it.deviceName ?: "" }
            }
            done(state)
        }
    }

    private fun stateMap(
        connected: Boolean,
        isOwner: Boolean,
        owner: String?,
        ssid: String?,
    ): Map<String, Any?> = mapOf(
        "type" to "state",
        "connected" to connected,
        "isOwner" to isOwner,
        "ownerAddress" to owner,
        "ssid" to ssid,
    )

    private fun errorMap(code: String, message: String): Map<String, Any?> =
        mapOf("type" to "error", "code" to code, "message" to message)

    private fun emit(event: Map<String, Any?>) {
        sink?.success(event)
    }

    private fun emitError(reason: Int) {
        emit(errorMap(codeFor(reason), messageFor(reason)))
    }

    private fun unsupported(result: MethodChannel.Result) {
        result.error("unsupported", messageFor(WifiP2pManager.P2P_UNSUPPORTED), null)
    }

    private fun replyListener(result: MethodChannel.Result) = object : WifiP2pManager.ActionListener {
        override fun onSuccess() {
            result.success(true)
        }

        override fun onFailure(reason: Int) {
            emitError(reason)
            result.error(codeFor(reason), messageFor(reason), null)
        }
    }

    private fun codeFor(reason: Int): String = when (reason) {
        WifiP2pManager.P2P_UNSUPPORTED -> "unsupported"
        WifiP2pManager.BUSY -> "busy"
        WifiP2pManager.NO_SERVICE_REQUESTS -> "no-service-requests"
        else -> "error"
    }

    private fun messageFor(reason: Int): String = when (reason) {
        WifiP2pManager.P2P_UNSUPPORTED -> "Wi-Fi Direct is not supported on this device"
        WifiP2pManager.BUSY -> "Wi-Fi Direct is busy"
        WifiP2pManager.NO_SERVICE_REQUESTS -> "No service requests are registered"
        else -> "Wi-Fi Direct failed"
    }

    private fun statusName(status: Int): String = when (status) {
        WifiP2pDevice.CONNECTED -> "connected"
        WifiP2pDevice.INVITED -> "invited"
        WifiP2pDevice.FAILED -> "failed"
        WifiP2pDevice.AVAILABLE -> "available"
        else -> "unavailable"
    }
}
