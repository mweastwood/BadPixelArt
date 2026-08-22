package com.mweastwood.bad_pixel_art

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mweastwood.bad_pixel_art/share_receiver"
    private var methodChannel: MethodChannel? = null
    private var initialSharedData: List<Map<String, Any?>>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialSharedData = processIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedData" -> {
                        val data = initialSharedData
                        initialSharedData = null
                        result.success(data)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val sharedData = processIntent(intent)
        if (sharedData.isNotEmpty()) {
            methodChannel?.invokeMethod("onSharedDataReceived", sharedData)
        }
    }

    private fun processIntent(intent: Intent?): List<Map<String, Any?>> {
        if (intent == null) return emptyList()
        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND != action && Intent.ACTION_SEND_MULTIPLE != action) {
            return emptyList()
        }

        val resultList = mutableListOf<Map<String, Any?>>()
        val extraText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val extraSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)

        if (Intent.ACTION_SEND == action) {
            val streamUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            } ?: intent.data

            if (streamUri != null) {
                val bytes = readBytesFromUri(streamUri)
                if (bytes != null) {
                    resultList.add(mapOf(
                        "bytes" to bytes,
                        "text" to extraText,
                        "subject" to extraSubject,
                        "mimeType" to type
                    ))
                }
            } else if (intent.clipData != null && intent.clipData!!.itemCount > 0) {
                val item = intent.clipData!!.getItemAt(0)
                val uri = item.uri
                if (uri != null) {
                    val bytes = readBytesFromUri(uri)
                    if (bytes != null) {
                        resultList.add(mapOf(
                            "bytes" to bytes,
                            "text" to (extraText ?: item.text?.toString()),
                            "subject" to extraSubject,
                            "mimeType" to type
                        ))
                    }
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val uriList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }

            uriList?.forEach { uri ->
                val bytes = readBytesFromUri(uri)
                if (bytes != null) {
                    resultList.add(mapOf(
                        "bytes" to bytes,
                        "text" to extraText,
                        "subject" to extraSubject,
                        "mimeType" to type
                    ))
                }
            }
        }

        return resultList
    }

    private fun readBytesFromUri(uri: Uri): ByteArray? {
        return try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                inputStream.readBytes()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
