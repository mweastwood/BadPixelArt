package com.mweastwood.bad_pixel_art

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
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
                    val canvasImageBytes = call.argument<ByteArray>("canvasImage")
                    val referenceImageBytes = call.argument<ByteArray>("referenceImage")
                    val promptText = call.argument<String>("prompt") ?: ""
                    val paletteColors = call.argument<List<String>>("paletteColors") ?: emptyList()

                    if (canvasImageBytes == null) {
                        result.error("invalid_argument", "canvasImage is missing", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val canvasGridString = String(canvasImageBytes, Charsets.UTF_8)
                            val finalCanvasGrid = if (canvasGridString.contains(Regex("[1-9]"))) {
                                canvasGridString
                            } else {
                                "The grid is completely empty (all 0s)."
                            }

                            var refShapeInstruction = ""
                            if (referenceImageBytes != null) {
                                val refString = String(referenceImageBytes, Charsets.UTF_8)
                                if (refString.startsWith("Sword")) {
                                    refShapeInstruction = "The user wants to draw a Sword."
                                } else if (refString.startsWith("Heart")) {
                                    refShapeInstruction = "The user wants to draw a Heart."
                                }
                            }

                            val systemInstruction = "You are an AI pixel art assistant co-creating an image with a user on a 64x64 grid (coordinates 0 to 63).\n" +
                                    "Available tools:\n" +
                                    "- \"line\": params [startX, startY, endX, endY]\n" +
                                    "- \"circle\": params [centerX, centerY, radius]\n" +
                                    "- \"fill\": params [startX, startY]\n" +
                                    "- \"hatch\": params [startX, startY] (alternating checkerboard pattern fill)\n\n" +
                                    "You must output EXACTLY a valid JSON block and nothing else. No explanation, no markdown tags. Example:\n" +
                                    "{\"tool\": \"line\", \"params\": [10, 15, 20, 25], \"color\": 2}"

                            val userTextPrompt = "User Instruction: \"$promptText\"\n" +
                                    "$refShapeInstruction\n" +
                                    "Color Palette Size: ${paletteColors.size} (Color indices are 0 to ${paletteColors.size - 1}).\n" +
                                    "Current grid layout serialized: $finalCanvasGrid\n\n" +
                                    "Output the single next stroke JSON now:"

                            val fullPrompt = "$systemInstruction\n\n$userTextPrompt"

                            val response = model.generateContent(
                                generateContentRequest(TextPart(fullPrompt)) {
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
