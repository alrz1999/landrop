package dev.landrop.landrop

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var hotspot: HotspotManager? = null
    private var wifiDirect: WifiDirectManager? = null

    private fun wifiDirectManager(): WifiDirectManager =
        wifiDirect ?: WifiDirectManager(this).also { wifiDirect = it }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.landrop/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        if (multicastLock == null) {
                            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wifi.createMulticastLock("landrop").apply {
                                setReferenceCounted(false)
                            }
                        }
                        multicastLock?.acquire()
                        result.success(null)
                    }
                    "release" -> {
                        multicastLock?.takeIf { it.isHeld }?.release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.landrop/service")
            .setMethodCallHandler { call, result ->
                val intent = Intent(this, LanDropService::class.java)
                when (call.method) {
                    "start" -> {
                        try {
                            // startForegroundService is API 26+; minSdk is 24.
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "update" -> {
                        // Dart ints arrive as Integer (or Long when large).
                        val shares = (call.argument<Any>("shares") as? Number)?.toInt() ?: 0
                        val browsers = (call.argument<Any>("browsers") as? Number)?.toInt() ?: 0
                        LanDropService.updateStatus(shares, browsers)
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        // Local-only hotspot for the "Connect without Wi-Fi" wizard (hotspot_service.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.landrop/hotspot")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "start" -> {
                        val manager = hotspot ?: HotspotManager(this).also { hotspot = it }
                        manager.start(result)
                    }
                    "stop" -> {
                        hotspot?.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        // Wi-Fi Direct assist (wifi_direct_service.dart, WifiDirectManager.kt).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.landrop/wifidirect")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "supported" -> result.success(wifiDirectManager().supported())
                    "discover" -> wifiDirectManager().discover(result)
                    "stopDiscover" -> wifiDirectManager().stopDiscover(result)
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (address.isNullOrEmpty()) {
                            result.error("error", "address missing", null)
                        } else {
                            val intent = (call.argument<Any>("groupOwnerIntent") as? Number)?.toInt()
                            wifiDirectManager().connect(address, intent, result)
                        }
                    }
                    "createGroup" -> wifiDirectManager().createGroup(result)
                    "disconnect" -> {
                        wifiDirect?.disconnect()
                        result.success(true)
                    }
                    "info" -> wifiDirectManager().info(result)
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.landrop/wifidirect/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    wifiDirectManager().sink = events
                }

                override fun onCancel(arguments: Any?) {
                    wifiDirect?.sink = null
                }
            })
    }

    override fun onDestroy() {
        wifiDirect?.destroy()
        wifiDirect = null
        multicastLock?.takeIf { it.isHeld }?.release()
        hotspot?.stop()
        hotspot = null
        super.onDestroy()
    }
}
