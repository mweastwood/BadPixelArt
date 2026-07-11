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
                    val referenceImageBytes = call.argument<ByteArray>("referenceImage")

                    if (promptText == null) {
                        result.error("invalid_argument", "prompt is missing", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        var canvasBitmap: Bitmap? = null
                        var referenceBitmap: Bitmap? = null
                        var combinedBitmap: Bitmap? = null
                        try {
                            canvasBitmap = if (canvasImageBytes != null && canvasImageBytes.isNotEmpty()) {
                                BitmapFactory.decodeByteArray(canvasImageBytes, 0, canvasImageBytes.size)
                            } else {
                                null
                            }
                            referenceBitmap = if (referenceImageBytes != null && referenceImageBytes.isNotEmpty()) {
                                BitmapFactory.decodeByteArray(referenceImageBytes, 0, referenceImageBytes.size)
                            } else {
                                null
                            }

                            val response = if (canvasBitmap != null && referenceBitmap != null) {
                                combinedBitmap = combineBitmaps(canvasBitmap, referenceBitmap)
                                val combinedPrompt = "$promptText\n\nNote: The attached image shows the current canvas on the left, and the reference image on the right."
                                model.generateContent(
                                    generateContentRequest(ImagePart(combinedBitmap), TextPart(combinedPrompt)) {
                                        temperature = 0.7f
                                    }
                                )
                            } else if (canvasBitmap != null) {
                                model.generateContent(
                                    generateContentRequest(ImagePart(canvasBitmap), TextPart(promptText)) {
                                        temperature = 0.7f
                                    }
                                )
                            } else if (referenceBitmap != null) {
                                model.generateContent(
                                    generateContentRequest(ImagePart(referenceBitmap), TextPart(promptText)) {
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
                            referenceBitmap?.recycle()
                            combinedBitmap?.recycle()
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun combineBitmaps(left: Bitmap, right: Bitmap): Bitmap {
        val width = left.width + right.width
        val height = if (left.height > right.height) left.height else right.height
        val combined = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(combined)
        canvas.drawBitmap(left, 0f, 0f, null)
        canvas.drawBitmap(right, left.width.toFloat(), 0f, null)
        return combined
    }
}
