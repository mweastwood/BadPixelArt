package com.mweastwood.bad_pixel_art

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Part
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.ImagePart
import com.google.mlkit.genai.prompt.generateContentRequest
import android.graphics.BitmapFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.collect
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mweastwood.bad_pixel_art/aicore"
    private val ioScope = CoroutineScope(Dispatchers.IO)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val model = Generation.getClient()

            when (call.method) {
                "checkStatus" -> {
                    ioScope.launch {
                        try {
                            val status = model.checkStatus()
                            val statusStr = when (status) {
                                FeatureStatus.AVAILABLE -> "available"
                                FeatureStatus.DOWNLOADABLE -> "downloadable"
                                FeatureStatus.DOWNLOADING -> "downloading"
                                else -> "unavailable"
                            }
                            withContext(Dispatchers.Main) {
                                result.success(statusStr)
                            }
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error checking status: ${e.message}", e)
                            withContext(Dispatchers.Main) {
                                result.success("unavailable")
                            }
                        }
                    }
                }
                "triggerDownload" -> {
                    ioScope.launch {
                        try {
                            model.download().collect { downloadStatus ->
                                Log.d("MainActivity", "Download status: $downloadStatus")
                            }
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error triggering download: ${e.message}", e)
                        }
                    }
                    result.success(null)
                }
                "getNextStroke" -> {
                    val promptText = call.argument<String>("prompt")
                    val canvasImageBytes = call.argument<ByteArray>("canvasImage")
                    val referenceImageBytes = call.argument<ByteArray>("referenceImage")

                    if (promptText == null) {
                        result.error("invalid_argument", "prompt is missing", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val parts = mutableListOf<Part>()

                            if (canvasImageBytes != null && canvasImageBytes.isNotEmpty()) {
                                val canvasBitmap = BitmapFactory.decodeByteArray(canvasImageBytes, 0, canvasImageBytes.size)
                                if (canvasBitmap != null) {
                                    parts.add(ImagePart(canvasBitmap))
                                }
                            }

                            if (referenceImageBytes != null && referenceImageBytes.isNotEmpty()) {
                                val referenceBitmap = BitmapFactory.decodeByteArray(referenceImageBytes, 0, referenceImageBytes.size)
                                if (referenceBitmap != null) {
                                    parts.add(ImagePart(referenceBitmap))
                                }
                            }

                            parts.add(TextPart(promptText))

                            val response = model.generateContent(
                                generateContentRequest(*parts.toTypedArray()) {
                                    // Optional config
                                }
                            )

                            val responseText = response.candidates.firstOrNull()?.text ?: ""

                            withContext(Dispatchers.Main) {
                                result.success(responseText)
                            }
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error generating content: ${e.message}", e)
                            withContext(Dispatchers.Main) {
                                result.error("generation_failed", e.message, null)
                            }
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
