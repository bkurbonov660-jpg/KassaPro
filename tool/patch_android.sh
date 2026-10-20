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
  sed -i 's|signingConfigs.getByName("debug")|signingConfigs.getByName("doramaRelease")|g' "$F"
  grep -q 'getByName("doramaRelease")' "$F" || echo "::warning::release-подпись не применилась (kts)"
elif [ -f "$APP/build.gradle" ]; then
  F=$APP/build.gradle
  if ! grep -q 'doramaRelease' "$F"; then
    sed -i 's|^android {|android {\n    signingConfigs {\n        doramaRelease {\n            def kp = new java.util.Properties()\n            kp.load(new java.io.FileInputStream(rootProject.file("key.properties")))\n            keyAlias kp.getProperty("keyAlias")\n            keyPassword kp.getProperty("keyPassword")\n            storeFile file(kp.getProperty("storeFile"))\n            storePassword kp.getProperty("storePassword")\n        }\n    }|' "$F"
  fi
  sed -i 's|signingConfig signingConfigs.debug|signingConfig signingConfigs.doramaRelease|g' "$F"
  grep -q 'signingConfigs.doramaRelease' "$F" || echo "::warning::release-подпись не применилась (groovy)"
else
  echo "::error::build.gradle не найден"; exit 1
fi

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
            val ch = NotificationChannel(CHANNEL, "Новые серии", NotificationManager.IMPORTANCE_DEFAULT)
            ch.description = "Уведомления о выходе новых серий из списка Смотрю"
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
sed -i "s/__PKG__/$PKG/g" "$KDIR/MainActivity.kt" "$KDIR/Notify.kt"

mkdir -p "$APP/src/main/res/drawable" "$APP/src/main/res/raw"
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
<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_pulse" />
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
           '        </receiver>\n    ') % (pkg, pkg)
    s = s.replace('</application>', rec + '</application>', 1)
open(p, 'w', encoding='utf-8').write(s)
EOF_PY
grep -q 'NotifReceiver' "$M" || { echo "::error::receivers не добавлены в манифест"; exit 1; }
echo "Native part patched: $PKG"
echo "Android patched"
