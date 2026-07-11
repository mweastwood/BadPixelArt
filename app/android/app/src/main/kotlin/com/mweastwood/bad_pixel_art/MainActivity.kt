package com.mweastwood.bad_pixel_art

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.ImagePart
import com.google.mlkit.genai.prompt.generateContentRequest
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Canvas
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

                    if (promptText == null) {
                        result.error("invalid_argument", "prompt is missing", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        var canvasBitmap: Bitmap? = null
                        try {
                            canvasBitmap = if (canvasImageBytes != null && canvasImageBytes.isNotEmpty()) {
                                BitmapFactory.decodeByteArray(canvasImageBytes, 0, canvasImageBytes.size)
                            } else {
                                null
                            }

                            val response = if (canvasBitmap != null) {
                                model.generateContent(
                                    generateContentRequest(ImagePart(canvasBitmap), TextPart(promptText)) {
                                        temperature = 0.7f
                                    }
                                )
                            } else {
                                model.generateContent(
                                    generateContentRequest(TextPart(promptText)) {
                                        temperature = 0.7f
                                    }
                                )
                            }

                            val responseText = response.candidates.firstOrNull()?.text ?: ""

                            withContext(Dispatchers.Main) {
                                result.success(responseText)
                            }
                        } catch (e: Throwable) {
                            Log.e("MainActivity", "Error generating content: ${e.message}", e)
                            withContext(Dispatchers.Main) {
                                result.error("generation_failed", e.message, null)
                            }
                        } finally {
                            canvasBitmap?.recycle()
                        }
                    }
                }
                "suggestPalette" -> {
                    val referenceImageBytes = call.argument<ByteArray>("referenceImage")
                    if (referenceImageBytes == null || referenceImageBytes.isEmpty()) {
                        result.error("invalid_argument", "referenceImage is missing or empty", null)
                        return@setMethodCallHandler
                    }
                    val promptText = "Analyze this reference image and suggest a palette of exactly 16 colors. Output a JSON array containing exactly 16 hex color strings (e.g. [\"#ff0000\", \"#00ff00\", ...]). Output nothing else."

                    ioScope.launch {
                        var referenceBitmap: Bitmap? = null
                        try {
                            referenceBitmap = BitmapFactory.decodeByteArray(referenceImageBytes, 0, referenceImageBytes.size)
                            if (referenceBitmap == null) {
                                withContext(Dispatchers.Main) {
                                    result.error("invalid_argument", "Failed to decode referenceImage bytes", null)
                                }
                                return@launch
                            }
                            val response = model.generateContent(
                                generateContentRequest(ImagePart(referenceBitmap), TextPart(promptText)) {
                                    temperature = 0.5f
                                }
                            )
                            val responseText = response.candidates.firstOrNull()?.text ?: ""
                            withContext(Dispatchers.Main) {
                                result.success(responseText)
                            }
                        } catch (e: Throwable) {
                            Log.e("MainActivity", "Error suggesting palette: ${e.message}", e)
                            withContext(Dispatchers.Main) {
                                result.error("generation_failed", e.message, null)
                            }
                        } finally {
                            referenceBitmap?.recycle()
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
