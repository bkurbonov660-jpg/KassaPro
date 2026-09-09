package com.obanstudio.oban_downloader

import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.obanstudio.downloader/shared"
    private var sharedLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (text != null) {
                // Извлекаем чистую ссылку из текста (YouTube часто добавляет заголовок перед ссылкой)
                val regex = Regex("""https?://[^\s]+""")
                val match = regex.find(text)
                sharedLink = match?.value ?: text
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedLink" -> {
                    result.success(sharedLink)
                    sharedLink = null
                }
                "scanMediaFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType")
                    if (filePath != null) {
                        // Регистрация в системной галерее телефона
                        MediaScannerConnection.scanFile(context, arrayOf(filePath), arrayOf(mimeType), null)
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
