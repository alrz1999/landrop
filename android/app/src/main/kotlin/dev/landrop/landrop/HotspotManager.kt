package dev.landrop.landrop

import android.annotation.TargetApi
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * Android local-only hotspot (API 26+) for the "Connect without Wi-Fi" wizard.
 * Dart asks for the runtime permission first (hotspot_service.dart).
 * Every method and callback runs on the main thread.
 */
class HotspotManager(context: Context) {
    private val wifi =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    // A WifiManager.LocalOnlyHotspotReservation (API 26+). Typed Any so this class
    // never references the API 26 type in a field on API 24-25.
    private var reservation: Any? = null
    private var credentials: Map<String, Any?>? = null
    private var pending: MethodChannel.Result? = null
    private var stopRequested = false

    /** Answers {ssid, password, gateway?} or an error code (see hotspot_service.dart). */
    fun start(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unsupported", "Needs Android 8.0 or newer", null)
            return
        }
        val current = credentials
        if (reservation != null && current != null) {
            result.success(current)
            return
        }
        if (pending != null) {
            result.error("busy", "A hotspot is already starting", null)
            return
        }
        pending = result
        stopRequested = false
        try {
            startLocalOnly()
        } catch (e: SecurityException) {
            fail("permission", e.message ?: "permission missing")
        } catch (e: IllegalStateException) {
            fail("busy", e.message ?: "a hotspot request is already active")
        } catch (e: Exception) {
            fail("failed", e.message ?: e.toString())
        }
    }

    /** Releases the hotspot (also called from MainActivity.onDestroy). */
    fun stop() {
        stopRequested = true
        fail("cancelled", "Hotspot stopped")
        val r = reservation
        reservation = null
        credentials = null
        if (r != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            closeReservation(r)
        }
    }

    private fun fail(code: String, message: String) {
        val p = pending
        pending = null
        try {
            p?.error(code, message, null)
        } catch (e: Exception) {
        }
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun closeReservation(r: Any) {
        try {
            (r as WifiManager.LocalOnlyHotspotReservation).close()
        } catch (e: Exception) {
        }
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun startLocalOnly() {
        wifi.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
            override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                if (stopRequested) {
                    closeReservation(res)
                    return
                }
                reservation = res
                val creds = readCredentials(res)
                credentials = creds
                val p = pending
                pending = null
                try {
                    p?.success(creds)
                } catch (e: Exception) {
                }
            }

            override fun onStopped() {
                reservation = null
                credentials = null
            }

            override fun onFailed(reason: Int) {
                fail(failureCode(reason), "Android could not start the hotspot (reason $reason)")
            }
        }, Handler(Looper.getMainLooper()))
    }

    @Suppress("DEPRECATION")
    @TargetApi(Build.VERSION_CODES.O)
    private fun readCredentials(res: WifiManager.LocalOnlyHotspotReservation): Map<String, Any?> {
        var ssid: String? = null
        var password: String? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val config = res.softApConfiguration
            ssid = config.ssid
            password = config.passphrase
        } else {
            val config = res.wifiConfiguration
            if (config != null) {
                ssid = config.SSID
                password = config.preSharedKey
            }
        }
        return mapOf(
            "ssid" to unquote(ssid),
            "password" to unquote(password),
            "gateway" to findApAddress()
        )
    }

    private fun unquote(s: String?): String? =
        if (s != null && s.length >= 2 && s.startsWith("\"") && s.endsWith("\"")) {
            s.substring(1, s.length - 1)
        } else {
            s
        }

    // LocalOnlyHotspotCallback.ERROR_NO_CHANNEL = 1, ERROR_GENERIC = 2,
    // ERROR_INCOMPATIBLE_MODE = 3, ERROR_TETHERING_DISALLOWED = 4.
    private fun failureCode(reason: Int): String = when (reason) {
        1 -> "no-channel"
        3 -> "incompatible-mode"
        4 -> "tethering-disallowed"
        else -> "failed"
    }

    /** This device's IPv4 address on the hotspot interface, if it is up yet. */
    private fun findApAddress(): String? {
        try {
            val ifaces = NetworkInterface.getNetworkInterfaces() ?: return null
            for (ni in ifaces.toList()) {
                val name = ni.name ?: continue
                if (!(name.startsWith("ap") || name.startsWith("swlan") || name.startsWith("softap"))) {
                    continue
                }
                for (addr in ni.inetAddresses.toList()) {
                    if (addr is Inet4Address && !addr.isLoopbackAddress) return addr.hostAddress
                }
            }
        } catch (e: Exception) {
        }
        return null
    }
}
