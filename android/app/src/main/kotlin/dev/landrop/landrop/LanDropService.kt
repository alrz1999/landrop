package dev.landrop.landrop

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder

/** Keeps the process (and the HTTPS server inside it) alive while the app is in the background. */
class LanDropService : Service() {
    companion object {
        private const val CHANNEL_ID = "landrop_service"
        private const val NOTIFICATION_ID = 1

        // Last counts from Dart (MethodChannel "update"); kept here so a service started later shows them too.
        @Volatile
        private var activeShares = 0

        @Volatile
        private var connectedBrowsers = 0

        // The running service, if any. Set and cleared on the main thread.
        private var instance: LanDropService? = null

        /** Called by MainActivity on the main thread. Re-posts the notification if the service is running. */
        fun updateStatus(shares: Int, browsers: Int) {
            activeShares = if (shares < 0) 0 else shares
            connectedBrowsers = if (browsers < 0) 0 else browsers
            instance?.repostNotification()
        }

        /** "Ready to receive files on your network", or e.g. "Ready to receive · 2 active shares · 1 browser connected". */
        fun statusText(context: Context, shares: Int, browsers: Int): String {
            val res = context.resources
            if (shares <= 0 && browsers <= 0) return res.getString(R.string.status_ready)
            val parts = ArrayList<String>()
            parts.add(res.getString(R.string.status_ready_short))
            if (shares > 0) parts.add(res.getQuantityString(R.plurals.status_shares, shares, shares))
            if (browsers > 0) parts.add(res.getQuantityString(R.plurals.status_browsers, browsers, browsers))
            return parts.joinToString(" · ")
        }
    }

    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    /** Notification.Builder(Context, String) exists only on API 26+; minSdk is 24. */
    @Suppress("DEPRECATION")
    private fun newBuilder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

    private fun buildNotification(): Notification =
        newBuilder()
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(statusText(this, activeShares, connectedBrowsers))
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    internal fun repostNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Same id as startForeground: replaces the foreground notification in place.
        nm.notify(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.notification_channel_name),
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        instance = this
        if (wifiLock == null) {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "landrop").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        return START_STICKY
    }

    /** App swiped away from Recents: stop everything, including the server in this process. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        wifiLock?.takeIf { it.isHeld }?.release()
        wifiLock = null
        super.onDestroy()
    }
}
