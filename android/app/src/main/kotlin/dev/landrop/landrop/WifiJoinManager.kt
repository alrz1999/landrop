package dev.landrop.landrop

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

/**
 * Joins a Wi-Fi network named by a scanned QR code (wifi_join_service.dart).
 *
 * API 29+: WifiNetworkSpecifier + requestNetwork. Android shows its own
 * confirmation dialog; the network is private to this app and goes away on
 * [leave]. API 24-28: legacy addNetwork/enableNetwork, best effort.
 *
 * `join` replies true once the request is started; the outcome arrives on
 * [sink] as {type: connected|failed|lost}. Everything runs on the main thread.
 */
class WifiJoinManager(context: Context) {
    private val app = context.applicationContext
    private val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
    @Suppress("DEPRECATION")
    private val wifi = app.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    private val main = Handler(Looper.getMainLooper())

    /** Set by the EventChannel stream handler (MainActivity). */
    var sink: EventChannel.EventSink? = null

    private var callback: ConnectivityManager.NetworkCallback? = null
    private var timeout: Runnable? = null
    private var legacyNetId = -1
    private var reported = false

    fun join(
        ssid: String,
        password: String,
        security: String,
        hidden: Boolean,
        result: MethodChannel.Result
    ) {
        if (cm == null) {
            result.error("unsupported", "No connectivity service", null)
            return
        }
        release()
        reported = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (security == "wep") {
                    result.error("unsupported-security", "WEP networks cannot be joined", null)
                    return
                }
                joinModern(cm, ssid, password, security, hidden)
            } else {
                joinLegacy(cm, ssid, password, security, hidden)
            }
            result.success(true)
        } catch (e: SecurityException) {
            release()
            result.error("permission", e.message ?: "permission missing", null)
        } catch (e: Exception) {
            release()
            result.error("failed", e.message ?: e.javaClass.simpleName, null)
        }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.Q)
    private fun joinModern(
        cm: ConnectivityManager,
        ssid: String,
        password: String,
        security: String,
        hidden: Boolean
    ) {
        val builder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (hidden) builder.setIsHiddenSsid(true)
        if (security != "open") {
            if (security == "wpa3" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setWpa3Passphrase(password)
            } else {
                builder.setWpa2Passphrase(password)
            }
        }
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .setNetworkSpecifier(builder.build())
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (callback !== this) return
                cm.bindProcessToNetwork(network)
                reportConnected(cm, network, ssid)
            }

            override fun onUnavailable() {
                if (callback !== this) return
                fail("timeout", "The network was not joined (declined, wrong password or out of range)")
            }

            override fun onLost(network: Network) {
                if (callback !== this) return
                cm.bindProcessToNetwork(null)
                if (reported) {
                    sink?.success(mapOf("type" to "lost"))
                } else {
                    fail("lost", "The network went away")
                }
            }
        }
        callback = cb
        // API 26+ overload with Handler and timeout; minSdk 24 but this branch is API 29+.
        cm.requestNetwork(request, cb, main, TIMEOUT_MS)
    }

    @Suppress("DEPRECATION")
    private fun joinLegacy(
        cm: ConnectivityManager,
        ssid: String,
        password: String,
        security: String,
        hidden: Boolean
    ) {
        val w = wifi ?: throw IllegalStateException("No Wi-Fi service")
        if (!w.isWifiEnabled) w.isWifiEnabled = true
        val conf = WifiConfiguration()
        conf.SSID = "\"" + ssid + "\""
        conf.hiddenSSID = hidden
        when (security) {
            "open" -> conf.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
            "wep" -> {
                conf.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
                conf.wepKeys[0] = "\"" + password + "\""
                conf.wepTxKeyIndex = 0
            }
            else -> conf.preSharedKey = "\"" + password + "\""
        }
        val id = w.addNetwork(conf)
        if (id == -1) throw IllegalStateException("Android refused to add the network")
        legacyNetId = id
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (callback !== this) return
                val current = try {
                    w.connectionInfo?.ssid
                } catch (e: Exception) {
                    null
                }
                if (current == "\"" + ssid + "\"") {
                    cm.bindProcessToNetwork(network)
                    reportConnected(cm, network, ssid)
                }
            }

            override fun onLost(network: Network) {
                if (callback !== this || !reported) return
                sink?.success(mapOf("type" to "lost"))
            }
        }
        callback = cb
        cm.registerNetworkCallback(request, cb)
        w.disconnect()
        w.enableNetwork(id, true)
        w.reconnect()
        val t = Runnable { fail("timeout", "The network was not joined in time") }
        timeout = t
        main.postDelayed(t, TIMEOUT_MS.toLong())
    }

    private fun reportConnected(cm: ConnectivityManager, network: Network, ssid: String) {
        if (reported) return
        reported = true
        timeout?.let { main.removeCallbacks(it) }
        timeout = null
        val addresses = ArrayList<String>()
        var gateway: String? = null
        val props = cm.getLinkProperties(network)
        if (props != null) {
            for (la in props.linkAddresses) {
                val a = la.address
                if (a is Inet4Address) addresses.add(a.hostAddress ?: continue)
            }
            for (r in props.routes) {
                val g = r.gateway
                if (r.isDefaultRoute && g is Inet4Address) {
                    gateway = g.hostAddress
                    break
                }
            }
        }
        sink?.success(
            mapOf(
                "type" to "connected",
                "ssid" to ssid,
                "gateway" to gateway,
                "addresses" to addresses
            )
        )
    }

    private fun fail(code: String, message: String) {
        if (reported) return
        release()
        sink?.success(mapOf("type" to "failed", "code" to code, "message" to message))
    }

    /** Drops the request, the legacy entry and the process binding. */
    @Suppress("DEPRECATION")
    private fun release() {
        timeout?.let { main.removeCallbacks(it) }
        timeout = null
        val cb = callback
        callback = null
        if (cb != null) {
            try {
                cm?.unregisterNetworkCallback(cb)
            } catch (e: Exception) {
                // Already unregistered.
            }
        }
        try {
            cm?.bindProcessToNetwork(null)
        } catch (e: Exception) {
            // Nothing bound.
        }
        if (legacyNetId != -1) {
            try {
                wifi?.removeNetwork(legacyNetId)
            } catch (e: Exception) {
                // Ignore.
            }
            legacyNetId = -1
        }
    }

    fun leave() {
        release()
        reported = false
    }

    fun destroy() {
        release()
        sink = null
    }

    companion object {
        private const val TIMEOUT_MS = 60_000
    }
}
