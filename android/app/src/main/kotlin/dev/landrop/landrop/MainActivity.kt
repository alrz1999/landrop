package dev.landrop.landrop

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

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
    }

    override fun onDestroy() {
        multicastLock?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }
}
