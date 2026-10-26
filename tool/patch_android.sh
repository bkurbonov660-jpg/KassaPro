#!/bin/bash
# Патч Android-проекта: интернет, название, подпись release-ключом
set -e
APP=android/app
M=$APP/src/main/AndroidManifest.xml

if ! grep -q 'android.permission.INTERNET' "$M"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$M"
fi
sed -i 's#android:label="[^"]*"#android:label="Дорама Пульс"#' "$M"

if [ -f "$APP/build.gradle.kts" ]; then
  F=$APP/build.gradle.kts
  if ! grep -q 'import java.util.Properties' "$F"; then
    sed -i '1i import java.util.Properties\nimport java.io.FileInputStream' "$F"
  fi
  if ! grep -q 'doramaRelease' "$F"; then
    sed -i 's|^android {|android {\n    signingConfigs {\n        create("doramaRelease") {\n            val kp = Properties()\n            kp.load(FileInputStream(rootProject.file("key.properties")))\n            keyAlias = kp.getProperty("keyAlias")\n            keyPassword = kp.getProperty("keyPassword")\n            storeFile = file(kp.getProperty("storeFile"))\n            storePassword = kp.getProperty("storePassword")\n        }\n    }|' "$F"
  fi
  sed -i 's|signingConfigs.getByName("debug")|signingConfigs.getByName("doramaRelease")\n            isMinifyEnabled = false\n            isShrinkResources = false|g' "$F"
  grep -q 'getByName("doramaRelease")' "$F" || echo "::warning::release-подпись не применилась (kts)"
elif [ -f "$APP/build.gradle" ]; then
  F=$APP/build.gradle
  if ! grep -q 'doramaRelease' "$F"; then
    sed -i 's|^android {|android {\n    signingConfigs {\n        doramaRelease {\n            def kp = new java.util.Properties()\n            kp.load(new java.io.FileInputStream(rootProject.file("key.properties")))\n            keyAlias kp.getProperty("keyAlias")\n            keyPassword kp.getProperty("keyPassword")\n            storeFile file(kp.getProperty("storeFile"))\n            storePassword kp.getProperty("storePassword")\n        }\n    }|' "$F"
  fi
  sed -i 's|signingConfig signingConfigs.debug|signingConfig signingConfigs.doramaRelease\n            minifyEnabled false\n            shrinkResources false|g' "$F"
  grep -q 'signingConfigs.doramaRelease' "$F" || echo "::warning::release-подпись не применилась (groovy)"
else
  echo "::error::build.gradle не найден"; exit 1
fi

cat > "$APP/proguard-rules.pro" << 'EOF_PROGUARD'
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class kotlin.coroutines.** { *; }
-dontwarn io.flutter.plugins.**
EOF_PROGUARD

# ── Нативная часть: уведомления о новых сериях, сохранение и открытие бэкапа ──
MA=$(find "$APP/src/main" \( -name 'MainActivity.kt' -o -name 'MainActivity.java' \) | head -n 1)
if [ -z "$MA" ]; then echo "::error::MainActivity не найден"; exit 1; fi
KDIR=$(dirname "$MA")
PKG=$(grep -m1 -E '^package ' "$MA" | sed -E 's/^package[[:space:]]+([A-Za-z0-9_.]+).*/\1/')
[ -n "$PKG" ] || PKG=com.dorama.doramapulse
rm -f "$KDIR/MainActivity.java" "$KDIR/MainActivity.kt"
cat > "$KDIR/MainActivity.kt" << 'EOF_KT_MAIN'
package __PKG__

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val reqSave = 7701
    private val reqPick = 7702
    private var pendingResult: MethodChannel.Result? = null
    private var pendingText: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dp/native").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "notifPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7731)
                        }
                        result.success(true)
                    }
                    "notifSchedule" -> {
                        val json = call.arguments as? String ?: "[]"
                        DpNotify.scheduleAll(applicationContext, json)
                        result.success(true)
                    }
                    "notifCancel" -> {
                        DpNotify.cancelAll(applicationContext)
                        result.success(true)
                    }
                    "updateWidgets" -> {
                        val json = call.arguments as? String ?: "{}"
                        DpWidgets.saveAndRefresh(applicationContext, json)
                        result.success(true)
                    }
                    "pinWidget" -> {
                        val kind = call.arguments as? String ?: "countdown"
                        val ok = DpWidgets.requestPin(applicationContext, kind)
                        result.success(ok)
                    }
                    "notifShow" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = (args?.get("id") as? Number)?.toInt() ?: 7799
                        val title = args?.get("title") as? String ?: "Дорама Пульс"
                        val body = args?.get("body") as? String ?: ""
                        if (body.isNotEmpty()) {
                            DpNotify.show(applicationContext, id, title, body)
                        }
                        result.success(true)
                    }
                    "saveFile" -> {
                        if (pendingResult != null) {
                            result.error("busy", "Операция уже выполняется", null)
                        } else {
                            val args = call.arguments as? Map<*, *>
                            val name = args?.get("name") as? String ?: "dorama_pulse_backup.json"
                            pendingText = args?.get("text") as? String ?: ""
                            pendingResult = result
                            val i = Intent(Intent.ACTION_CREATE_DOCUMENT)
                            i.addCategory(Intent.CATEGORY_OPENABLE)
                            i.type = "application/json"
                            i.putExtra(Intent.EXTRA_TITLE, name)
                            startActivityForResult(i, reqSave)
                        }
                    }
                    "pickFile" -> {
                        if (pendingResult != null) {
                            result.error("busy", "Операция уже выполняется", null)
                        } else {
                            pendingResult = result
                            val i = Intent(Intent.ACTION_OPEN_DOCUMENT)
                            i.addCategory(Intent.CATEGORY_OPENABLE)
                            i.type = "*/*"
                            startActivityForResult(i, reqPick)
                        }
                    }
                    "fileWrite" -> {
                        val args = call.arguments as? Map<*, *>
                        val name = (args?.get("name") as? String ?: "").replace(Regex("[^A-Za-z0-9_.]"), "")
                        val text = args?.get("text") as? String ?: ""
                        if (name.isEmpty()) {
                            result.success(false)
                        } else {
                            Thread {
                                var ok = false
                                try {
                                    val f = java.io.File(filesDir, name)
                                    val tmp = java.io.File(filesDir, name + ".tmp")
                                    tmp.writeText(text, Charsets.UTF_8)
                                    ok = tmp.renameTo(f)
                                    if (!ok) {
                                        f.writeText(text, Charsets.UTF_8)
                                        tmp.delete()
                                        ok = true
                                    }
                                } catch (e: Exception) {
                                    ok = false
                                }
                                runOnUiThread { result.success(ok) }
                            }.start()
                        }
                    }
                    "fileRead" -> {
                        val name = (call.arguments as? String ?: "").replace(Regex("[^A-Za-z0-9_.]"), "")
                        Thread {
                            var s: String? = null
                            try {
                                val f = java.io.File(filesDir, name)
                                if (name.isNotEmpty() && f.exists()) s = f.readText(Charsets.UTF_8)
                            } catch (e: Exception) {
                                s = null
                            }
                            runOnUiThread { result.success(s) }
                        }.start()
                    }
                    "prefsAll" -> {
                        val out = HashMap<String, String>()
                        try {
                            val spOld = applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                            for ((k, v) in spOld.all) {
                                if (v is String && k.startsWith("flutter.")) {
                                    out[k.removePrefix("flutter.")] = v
                                }
                            }
                        } catch (e: Exception) {}
                        try {
                            val sp = applicationContext.getSharedPreferences("dp_prefs", MODE_PRIVATE)
                            for ((k, v) in sp.all) {
                                if (v is String) out[k] = v
                            }
                        } catch (e: Exception) {}
                        result.success(out)
                    }
                    "prefWrite" -> {
                        val args = call.arguments as? Map<*, *>
                        val k = args?.get("key") as? String ?: ""
                        val v = args?.get("value") as? String ?: ""
                        if (k.isEmpty()) {
                            result.success(false)
                        } else {
                            try {
                                applicationContext.getSharedPreferences("dp_prefs", MODE_PRIVATE)
                                    .edit().putString(k, v).apply()
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "prefRemove" -> {
                        val k = call.arguments as? String ?: ""
                        try {
                            if (k.isNotEmpty()) {
                                applicationContext.getSharedPreferences("dp_prefs", MODE_PRIVATE)
                                    .edit().remove(k).apply()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openUrl" -> {
                        val url = call.arguments as? String ?: ""
                        try {
                            val i = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "sendMail" -> {
                        val args = call.arguments as? Map<*, *>
                        val to = args?.get("to") as? String ?: ""
                        val subject = args?.get("subject") as? String ?: ""
                        val body = args?.get("body") as? String ?: ""
                        val i = Intent(Intent.ACTION_SENDTO)
                        i.data = android.net.Uri.parse("mailto:")
                        i.putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
                        i.putExtra(Intent.EXTRA_SUBJECT, subject)
                        i.putExtra(Intent.EXTRA_TEXT, body)
                        try {
                            startActivity(Intent.createChooser(i, "Написать разработчику"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                pendingResult = null
                result.error("native", e.message, null)
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqSave && requestCode != reqPick) return
        val r = pendingResult
        pendingResult = null
        if (r == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            if (requestCode == reqSave) r.success(false) else r.success(null)
            return
        }
        try {
            if (requestCode == reqSave) {
                val os = contentResolver.openOutputStream(uri, "wt")
                if (os == null) {
                    r.success(false)
                } else {
                    os.use { it.write(pendingText.toByteArray(Charsets.UTF_8)) }
                    pendingText = ""
                    r.success(true)
                }
            } else {
                val ins = contentResolver.openInputStream(uri)
                if (ins == null) {
                    r.success(null)
                } else {
                    val text = ins.use { String(it.readBytes(), Charsets.UTF_8) }
                    r.success(text)
                }
            }
        } catch (e: Exception) {
            r.error("io", e.message, null)
        }
    }
}
EOF_KT_MAIN
cat > "$KDIR/Notify.kt" << 'EOF_KT_NOTIFY'
package __PKG__

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

object DpNotify {
    private const val CHANNEL = "dp_episodes"
    private const val PREFS = "dp_notify"
    private const val KEY = "items"

    private fun flags(): Int {
        return if (Build.VERSION.SDK_INT >= 23) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun alarmIntent(ctx: Context, id: Int, title: String, body: String): PendingIntent {
        val i = Intent(ctx, NotifReceiver::class.java)
        i.action = "dp.episode.$id"
        i.putExtra("id", id)
        i.putExtra("title", title)
        i.putExtra("body", body)
        return PendingIntent.getBroadcast(ctx, id, i, flags())
    }

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(CHANNEL, "Новые серии и обновления базы", NotificationManager.IMPORTANCE_HIGH)
            ch.description = "Уведомления о выходе новых серий и обновлениях базы дорам"
            nm.createNotificationChannel(ch)
        }
    }

    @Suppress("DEPRECATION")
    private fun builder(ctx: Context): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else Notification.Builder(ctx)
    }

    fun show(ctx: Context, id: Int, title: String, body: String) {
        ensureChannel(ctx)
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        var icon = ctx.resources.getIdentifier("ic_stat_pulse", "drawable", ctx.packageName)
        if (icon == 0) icon = ctx.applicationInfo.icon
        val b = builder(ctx)
        b.setSmallIcon(icon)
        b.setContentTitle(title)
        b.setContentText(body)
        b.setStyle(Notification.BigTextStyle().bigText(body))
        b.setAutoCancel(true)
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        if (launch != null) {
            b.setContentIntent(PendingIntent.getActivity(ctx, 0, launch, flags()))
        }
        nm.notify(id, b.build())
    }

    fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val raw = prefs(ctx).getString(KEY, "[]") ?: "[]"
        try {
            val arr = JSONArray(raw)
            for (n in 0 until arr.length()) {
                val o = arr.optJSONObject(n) ?: continue
                val pi = alarmIntent(ctx, o.optInt("id"), o.optString("title"), o.optString("body"))
                am.cancel(pi)
                pi.cancel()
            }
        } catch (e: Exception) {
        }
        prefs(ctx).edit().putString(KEY, "[]").apply()
    }

    private fun arm(ctx: Context, arr: JSONArray) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (n in 0 until arr.length()) {
            val o = arr.optJSONObject(n) ?: continue
            val pi = alarmIntent(ctx, o.optInt("id"), o.optString("title"), o.optString("body"))
            val ts = o.optLong("ts", 0L)
            try {
                if (Build.VERSION.SDK_INT >= 23) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, ts, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, ts, pi)
                }
            } catch (e: Exception) {
            }
        }
    }

    fun scheduleAll(ctx: Context, json: String) {
        cancelAll(ctx)
        val keep = JSONArray()
        try {
            val arr = JSONArray(json)
            val now = System.currentTimeMillis()
            for (n in 0 until arr.length()) {
                val o = arr.optJSONObject(n) ?: continue
                if (o.optLong("ts", 0L) > now) keep.put(o)
            }
        } catch (e: Exception) {
        }
        prefs(ctx).edit().putString(KEY, keep.toString()).apply()
        arm(ctx, keep)
    }

    fun restore(ctx: Context) {
        val raw = prefs(ctx).getString(KEY, "[]") ?: "[]"
        try {
            val arr = JSONArray(raw)
            val keep = JSONArray()
            val now = System.currentTimeMillis()
            for (n in 0 until arr.length()) {
                val o = arr.optJSONObject(n) ?: continue
                if (o.optLong("ts", 0L) > now) keep.put(o)
            }
            prefs(ctx).edit().putString(KEY, keep.toString()).apply()
            arm(ctx, keep)
        } catch (e: Exception) {
        }
    }
}

class NotifReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "Дорама Пульс"
        val body = intent.getStringExtra("body") ?: ""
        if (body.isNotEmpty()) DpNotify.show(context, id, title, body)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            DpNotify.restore(context)
        } catch (e: Exception) {
        }
    }
}
EOF_KT_NOTIFY
cat > "$KDIR/Widgets.kt" << 'EOF_KT_WIDGETS'
package __PKG__

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject

object DpWidgets {
    private const val PREFS = "dp_widgets"
    private const val KEY = "data"

    private fun flags(): Int {
        return if (Build.VERSION.SDK_INT >= 23) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun launchIntent(ctx: Context): PendingIntent? {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
        return PendingIntent.getActivity(ctx, 0, launch, flags())
    }

    fun saveAndRefresh(ctx: Context, json: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
        refreshAll(ctx)
    }

    fun readData(ctx: Context): JSONObject {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "{}") ?: "{}"
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            JSONObject()
        }
    }

    fun refreshAll(ctx: Context) {
        val mgr = AppWidgetManager.getInstance(ctx)
        val d = readData(ctx)
        for (id in mgr.getAppWidgetIds(ComponentName(ctx, CountdownWidgetProvider::class.java))) {
            updateCountdown(ctx, mgr, id, d)
        }
        for (id in mgr.getAppWidgetIds(ComponentName(ctx, ScheduleWidgetProvider::class.java))) {
            updateSchedule(ctx, mgr, id, d)
        }
        for (id in mgr.getAppWidgetIds(ComponentName(ctx, StatsWidgetProvider::class.java))) {
            updateStats(ctx, mgr, id, d)
        }
    }

    fun requestPin(ctx: Context, kind: String): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        val mgr = ctx.getSystemService(AppWidgetManager::class.java) ?: return false
        if (!mgr.isRequestPinAppWidgetSupported) return false
        val cls = when (kind) {
            "schedule" -> ScheduleWidgetProvider::class.java
            "stats" -> StatsWidgetProvider::class.java
            else -> CountdownWidgetProvider::class.java
        }
        val provider = ComponentName(ctx, cls)
        return mgr.requestPinAppWidget(provider, null, null)
    }

    fun updateCountdown(ctx: Context, mgr: AppWidgetManager, id: Int, d: JSONObject) {
        val rv = RemoteViews(ctx.packageName, R.layout.widget_countdown)
        rv.setTextViewText(R.id.w_cd_badge, d.optString("cdBadge", "ПУЛЬС"))
        rv.setTextViewText(R.id.w_cd_title, d.optString("cdTitle", "Дорама Пульс"))
        rv.setTextViewText(R.id.w_cd_sub, d.optString("cdSub", "Добавьте дораму в список «Смотрю»"))
        rv.setTextViewText(R.id.w_cd_prog, d.optString("cdProg", "Таймер до следующей серии"))
        launchIntent(ctx)?.let { rv.setOnClickPendingIntent(R.id.w_cd_root, it) }
        mgr.updateAppWidget(id, rv)
    }

    fun updateSchedule(ctx: Context, mgr: AppWidgetManager, id: Int, d: JSONObject) {
        val rv = RemoteViews(ctx.packageName, R.layout.widget_schedule)
        rv.setTextViewText(R.id.w_sc_header, d.optString("schedHeader", "Расписание на сегодня"))
        rv.setTextViewText(R.id.w_sc_time, d.optString("updated", "ЭФИР"))
        rv.setTextViewText(R.id.w_sc_body, d.optString("schedBody", "Откройте приложение для синхронизации расписания"))
        launchIntent(ctx)?.let { rv.setOnClickPendingIntent(R.id.w_sc_root, it) }
        mgr.updateAppWidget(id, rv)
    }

    fun updateStats(ctx: Context, mgr: AppWidgetManager, id: Int, d: JSONObject) {
        val rv = RemoteViews(ctx.packageName, R.layout.widget_stats)
        rv.setTextViewText(R.id.w_st_main, d.optString("statsMain", "0 серий · 0 ч"))
        rv.setTextViewText(R.id.w_st_sub, d.optString("statsSub", "Ваша коллекция дорам"))
        rv.setTextViewText(R.id.w_st_radar, d.optString("radarLine", "Радар новых серий и любимых актёров"))
        launchIntent(ctx)?.let { rv.setOnClickPendingIntent(R.id.w_st_root, it) }
        mgr.updateAppWidget(id, rv)
    }
}

class CountdownWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val d = DpWidgets.readData(context)
        for (id in appWidgetIds) DpWidgets.updateCountdown(context, appWidgetManager, id, d)
    }
}

class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val d = DpWidgets.readData(context)
        for (id in appWidgetIds) DpWidgets.updateSchedule(context, appWidgetManager, id, d)
    }
}

class StatsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val d = DpWidgets.readData(context)
        for (id in appWidgetIds) DpWidgets.updateStats(context, appWidgetManager, id, d)
    }
}
EOF_KT_WIDGETS
sed -i "s/__PKG__/$PKG/g" "$KDIR/MainActivity.kt" "$KDIR/Notify.kt" "$KDIR/Widgets.kt"

mkdir -p "$APP/src/main/res/drawable" "$APP/src/main/res/layout" "$APP/src/main/res/xml" "$APP/src/main/res/values" "$APP/src/main/res/raw"

cat > "$APP/src/main/res/drawable/dp_widget_bg.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#16111D"/>
    <corners android:radius="20dp"/>
    <stroke android:width="1dp" android:color="#38304A"/>
</shape>
EOF_XML

cat > "$APP/src/main/res/drawable/dp_widget_pill_pk.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#2A2137"/>
    <corners android:radius="100dp"/>
    <stroke android:width="1dp" android:color="#FF7A9C"/>
</shape>
EOF_XML

cat > "$APP/src/main/res/drawable/dp_widget_pill_jd.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#1F1829"/>
    <corners android:radius="100dp"/>
    <stroke android:width="1dp" android:color="#5FD9B4"/>
</shape>
EOF_XML

cat > "$APP/src/main/res/layout/widget_countdown.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_cd_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/dp_widget_bg">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">

        <TextView
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="ДОРАМА ПУЛЬС · СМОТРЮ"
            android:textColor="#A99FB8"
            android:textSize="10.5sp"
            android:textStyle="bold"
            android:singleLine="true"
            android:ellipsize="end"/>

        <TextView
            android:id="@+id/w_cd_badge"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:background="@drawable/dp_widget_pill_pk"
            android:paddingLeft="10dp"
            android:paddingRight="10dp"
            android:paddingTop="3dp"
            android:paddingBottom="3dp"
            android:text="ПУЛЬС"
            android:textColor="#FF7A9C"
            android:textSize="11sp"
            android:textStyle="bold"/>
    </LinearLayout>

    <TextView
        android:id="@+id/w_cd_title"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="Любовь под прикрытием"
        android:textColor="#F5EEE6"
        android:textSize="16sp"
        android:textStyle="bold"
        android:maxLines="1"
        android:ellipsize="end"/>

    <TextView
        android:id="@+id/w_cd_sub"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text="Обратный отсчёт до следующей серии"
        android:textColor="#5FD9B4"
        android:textSize="12.5sp"
        android:textStyle="bold"
        android:maxLines="1"
        android:ellipsize="end"/>

    <TextView
        android:id="@+id/w_cd_prog"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text="Откройте приложение для синхронизации"
        android:textColor="#A99FB8"
        android:textSize="11.5sp"
        android:maxLines="1"
        android:ellipsize="end"/>
</LinearLayout>
EOF_XML

cat > "$APP/src/main/res/layout/widget_schedule.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_sc_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/dp_widget_bg">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">

        <TextView
            android:id="@+id/w_sc_header"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Расписание на сегодня"
            android:textColor="#F5EEE6"
            android:textSize="14sp"
            android:textStyle="bold"
            android:singleLine="true"
            android:ellipsize="end"/>

        <TextView
            android:id="@+id/w_sc_time"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:background="@drawable/dp_widget_pill_jd"
            android:paddingLeft="9dp"
            android:paddingRight="9dp"
            android:paddingTop="2dp"
            android:paddingBottom="2dp"
            android:text="ЭФИР"
            android:textColor="#5FD9B4"
            android:textSize="10.5sp"
            android:textStyle="bold"/>
    </LinearLayout>

    <TextView
        android:id="@+id/w_sc_body"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:lineSpacingExtra="3dp"
        android:text="Загрузка расписания серий на сегодня…"
        android:textColor="#A99FB8"
        android:textSize="12.5sp"
        android:maxLines="4"
        android:ellipsize="end"/>
</LinearLayout>
EOF_XML

cat > "$APP/src/main/res/layout/widget_stats.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_st_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/dp_widget_bg">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="МОЯ СТАТИСТИКА И РАДАР"
        android:textColor="#A99FB8"
        android:textSize="10.5sp"
        android:textStyle="bold"
        android:singleLine="true"/>

    <TextView
        android:id="@+id/w_st_main"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:text="0 серий · 0 ч"
        android:textColor="#FFC857"
        android:textSize="16sp"
        android:textStyle="bold"
        android:singleLine="true"
        android:ellipsize="end"/>

    <TextView
        android:id="@+id/w_st_sub"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="3dp"
        android:text="Смотрю: 0 · В планах: 0"
        android:textColor="#F5EEE6"
        android:textSize="12sp"
        android:singleLine="true"
        android:ellipsize="end"/>

    <TextView
        android:id="@+id/w_st_radar"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="5dp"
        android:text="Радар любимых актёров и премьер"
        android:textColor="#A99FB8"
        android:textSize="11.5sp"
        android:maxLines="2"
        android:ellipsize="end"/>
</LinearLayout>
EOF_XML

cat > "$APP/src/main/res/xml/widget_countdown_info.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/widget_countdown"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/dp_w_cd_desc"/>
EOF_XML

cat > "$APP/src/main/res/xml/widget_schedule_info.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/widget_schedule"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/dp_w_sc_desc"/>
EOF_XML

cat > "$APP/src/main/res/xml/widget_stats_info.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/widget_stats"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/dp_w_st_desc"/>
EOF_XML

cat > "$APP/src/main/res/values/dp_widget_strings.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="dp_w_cd_name">Дорама Пульс · Таймер серии</string>
    <string name="dp_w_cd_desc">Обратный отсчёт до следующей серии из списка «Смотрю»</string>
    <string name="dp_w_sc_name">Дорама Пульс · Расписание сегодня</string>
    <string name="dp_w_sc_desc">Серии корейских дорам, выходящие сегодня</string>
    <string name="dp_w_st_name">Дорама Пульс · Сводка и Радар</string>
    <string name="dp_w_st_desc">Статистика просмотра и ближайшие релизы любимых актёров</string>
</resources>
EOF_XML
cat > "$APP/src/main/res/drawable/ic_stat_pulse.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:pathData="M2,12 L7,12 L9.5,5 L13,19 L15.5,10 L17,12 L22,12"
        android:strokeColor="#FFFFFFFF"
        android:strokeWidth="2.4"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"/>
</vector>
EOF_XML
cat > "$APP/src/main/res/raw/keep.xml" << 'EOF_XML'
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_pulse,@layout/widget_countdown,@layout/widget_schedule,@layout/widget_stats,@xml/widget_countdown_info,@xml/widget_schedule_info,@xml/widget_stats_info" />
EOF_XML

python3 - "$M" "$PKG" << 'EOF_PY'
import sys
p, pkg = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8').read()
perms = ''
for perm in ('android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED'):
    if perm not in s:
        perms += '    <uses-permission android:name="%s"/>\n' % perm
if perms:
    s = s.replace('<application', perms + '    <application', 1)
if 'NotifReceiver' not in s:
    rec = ('    <receiver android:name="%s.NotifReceiver" android:exported="false"/>\n'
           '        <receiver android:name="%s.BootReceiver" android:exported="true">\n'
           '            <intent-filter>\n'
           '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
           '            </intent-filter>\n'
           '        </receiver>\n'
           '        <receiver android:name="%s.CountdownWidgetProvider" android:label="@string/dp_w_cd_name" android:exported="true">\n'
           '            <intent-filter>\n'
           '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
           '            </intent-filter>\n'
           '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_countdown_info"/>\n'
           '        </receiver>\n'
           '        <receiver android:name="%s.ScheduleWidgetProvider" android:label="@string/dp_w_sc_name" android:exported="true">\n'
           '            <intent-filter>\n'
           '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
           '            </intent-filter>\n'
           '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_schedule_info"/>\n'
           '        </receiver>\n'
           '        <receiver android:name="%s.StatsWidgetProvider" android:label="@string/dp_w_st_name" android:exported="true">\n'
           '            <intent-filter>\n'
           '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
           '            </intent-filter>\n'
           '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_stats_info"/>\n'
           '        </receiver>\n    ') % (pkg, pkg, pkg, pkg, pkg)
    s = s.replace('</application>', rec + '</application>', 1)
open(p, 'w', encoding='utf-8').write(s)
EOF_PY
grep -q 'NotifReceiver' "$M" || { echo "::error::receivers не добавлены в манифест"; exit 1; }
echo "Native part patched: $PKG"
echo "Android patched"
