package com.master.master_and_client

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.os.Build
import android.os.IBinder
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat

class MyAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var instance: MyAccessibilityService? = null
        @Volatile var currentApp: String? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val pkg = event.packageName?.toString()
            if (!pkg.isNullOrEmpty() && pkg != "com.android.systemui") {
                currentApp = pkg
            }
        }
    }

    override fun onInterrupt() {}

    fun performRemoteTap(x: Float, y: Float) {
        val path = Path().apply { moveTo(x, y) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 60))
            .build()
        dispatchGesture(gesture, null, null)
    }

    fun performRemoteSwipe(startX: Float, startY: Float, endX: Float, endY: Float) {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()
        dispatchGesture(gesture, null, null)
    }

    fun performGlobalAction(action: String) {
        val act = when (action) {
            "home" -> GLOBAL_ACTION_HOME
            "back" -> GLOBAL_ACTION_BACK
            "recents" -> GLOBAL_ACTION_RECENTS
            "lock" -> GLOBAL_ACTION_LOCK_SCREEN
            "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
            else -> GLOBAL_ACTION_HOME
        }
        performGlobalAction(act)
    }
}

class MonitoringForegroundService : Service() {
    private val CHANNEL_ID = "master_client_channel"
    private val NOTIF_ID = 1001

    override fun onCreate() {
        super.onCreate()
        createChannel()
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Master & Client")
            .setContentText("Служба согласованного контроля активна")
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(NOTIF_ID, notif)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY
    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Master & Client Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Фоновая служба мониторинга" }
            mgr.createNotificationChannel(ch)
        }
    }
}
