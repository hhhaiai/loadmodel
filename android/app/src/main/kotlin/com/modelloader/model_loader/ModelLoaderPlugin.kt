package com.modelloader.model_loader

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.speech.tts.TextToSpeech
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.File
import java.io.FileNotFoundException
import java.util.Locale
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OnnxValue
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.OrtSession.SessionOptions
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.log
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

class ModelLoaderPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private var nativeBridgeAvailable: Boolean = false

        init {
            nativeBridgeAvailable = try {
                System.loadLibrary("llama_bridge")
                true
            } catch (e: UnsatisfiedLinkError) {
                android.util.Log.e("ModelLoader", "Failed to load llama_bridge: ${e.message}")
                false
            }
        }
    }

    private external fun nativeLoadLlamaModel(
        modelPath: String,
        contextLength: Int,
        threads: Int,
        gpuLayers: Int,
        useGpu: Boolean,
    ): Boolean
    private external fun nativeLlamaFileExists(modelPath: String): Boolean
    private external fun nativeUnloadLlamaModel()
    private external fun nativeIsLlamaLoaded(): Boolean
    private external fun nativeChatLlama(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
        topK: Int,
        repeatPenalty: Double,
        seed: Int,
    ): String
    private external fun nativeChatLlamaMessages(
        roles: Array<String>,
        contents: Array<String>,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
        topK: Int,
        repeatPenalty: Double,
        seed: Int,
    ): String

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private lateinit var flutterAssets: FlutterPlugin.FlutterAssets
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    private fun validateLlmModelPath(rawPath: String): String? {
        val path = rawPath.trim()
        if (path.isEmpty()) {
            return null
        }

        return try {
            val canonical = File(path).canonicalFile
            if (!canonical.isFile) {
                return null
            }

            if (!canonical.name.lowercase().endsWith(".gguf")) {
                return null
            }

            val cacheCanonical = File(applicationContext.cacheDir, "models").canonicalFile
            val pathCanonical = canonical.path
            val cachePath = cacheCanonical.path
            if (pathCanonical != cachePath && !pathCanonical.startsWith(cachePath + File.separator)) {
                return null
            }

            pathCanonical
        } catch (_: Exception) {
            null
        }
    }

    private fun clampTemperature(value: Double): Double = value.coerceIn(0.0, 2.0)

    private fun clampTopP(value: Double): Double = value.coerceIn(0.05, 1.0)

    private fun clampTopK(value: Int): Int = value.coerceAtLeast(1)

    private fun clampRepeatPenalty(value: Double): Double = value.coerceIn(0.0, 2.0)

    private fun clampMaxTokens(value: Int): Int = value.coerceIn(1, 2048)

    private fun clampContextLength(value: Int): Int = value.coerceIn(512, 8192)

    private fun normalizeThreads(value: Int?): Int = (value ?: 0).coerceIn(0, 32)

    private fun normalizeGpuLayers(value: Int?, useGpu: Boolean): Int {
        if (!useGpu) {
            return 0
        }
        return (value ?: 0).coerceAtLeast(0)
    }

    private data class NativeChatMessages(
        val roles: Array<String>,
        val contents: Array<String>,
    )

    private fun normalizeChatRole(rawRole: Any?): String {
        return when (rawRole?.toString()?.trim()?.lowercase()) {
            "system" -> "system"
            "assistant" -> "assistant"
            else -> "user"
        }
    }

    private fun normalizeChatMessages(messages: List<Map<String, Any>>): NativeChatMessages? {
        val roles = ArrayList<String>(messages.size)
        val contents = ArrayList<String>(messages.size)

        for (message in messages) {
            val content = message["content"]?.toString() ?: ""
            if (content.trim().isEmpty()) {
                continue
            }

            roles.add(normalizeChatRole(message["role"]))
            contents.add(content)
        }

        if (roles.isEmpty()) {
            return null
        }

        return NativeChatMessages(
            roles = roles.toTypedArray(),
            contents = contents.toTypedArray(),
        )
    }

    private fun normalizeBundledAssetPath(rawPath: String): String? {
        val path = rawPath.trim()
        if (path.isEmpty() || path.startsWith("/") || path.contains("..")) {
            return null
        }

        return path
    }

    private fun stageBundledAsset(assetPath: String): String {
        val modelsRoot = File(applicationContext.cacheDir, "models").canonicalFile
        val relativePath = assetPath.removePrefix("assets/")
        val outputFile = File(modelsRoot, relativePath).canonicalFile
        val modelsRootPath = modelsRoot.path
        val outputPath = outputFile.path

        if (outputPath != modelsRootPath &&
            !outputPath.startsWith(modelsRootPath + File.separator)
        ) {
            throw SecurityException("Resolved asset path escaped models cache root")
        }

        if (outputFile.exists() && outputFile.length() > 0L) {
            return outputPath
        }

        outputFile.parentFile?.mkdirs()

        val assetLookupKey = flutterAssets.getAssetFilePathByName(assetPath)
        applicationContext.assets.open(assetLookupKey).use { input ->
            outputFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        return outputPath
    }

    // ONNX Runtime sessions
    private var ortEnv: OrtEnvironment? = null
    private var ocrSession: OrtSession? = null
    private var sttEncoderSession: OrtSession? = null
    private var sttDecoderSession: OrtSession? = null
    private var embeddingSession: OrtSession? = null

    // Text-to-Speech engine
    private var tts: TextToSpeech? = null
    private var ttsInitialized = false

    // Tokenizer for embedding models
    private var tokenizer: AndroidWordPieceTokenizer? = null

    // STT vocabulary for token decoding
    private var sttVocab: Map<Int, String>? = null
    private var sttAddedTokens: Map<String, Int>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        flutterAssets = binding.flutterAssets
        channel = MethodChannel(binding.binaryMessenger, "com.modelloader/model_runtime")
        channel.setMethodCallHandler(this)

        // Initialize ONNX Runtime environment
        try {
            ortEnv = OrtEnvironment.getEnvironment()
            android.util.Log.i("ModelLoader", "ONNX Runtime initialized")
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Failed to initialize ONNX Runtime: ${e.message}")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()

        if (nativeBridgeAvailable) {
            try {
                nativeUnloadLlamaModel()
            } catch (e: Throwable) {
                android.util.Log.w("ModelLoader", "Failed to unload native llama bridge on detach", e)
            }
        }
        llmLoaded = false

        // Cleanup ONNX sessions
        try {
            ocrSession?.close()
            sttEncoderSession?.close()
            sttDecoderSession?.close()
            embeddingSession?.close()
            ortEnv?.close()
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Error closing ONNX sessions: ${e.message}")
        }

        // Cleanup TTS
        try {
            tts?.shutdown()
            tts = null
            ttsInitialized = false
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Error closing TTS: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // Embedding Methods
            "loadEmbeddingModel" -> handleLoadEmbeddingModel(call, result)
            "unloadEmbeddingModel" -> handleUnloadEmbeddingModel(result)
            "getEmbedding" -> handleGetEmbedding(call, result)

            // OCR Methods
            "loadOCRModel" -> handleLoadOCRModel(call, result)
            "unloadOCRModel" -> handleUnloadOCRModel(result)
            "recognizeOCR" -> handleRecognizeOCR(call, result)

            // STT Methods
            "loadSTTModel" -> handleLoadSTTModel(call, result)
            "unloadSTTModel" -> handleUnloadSTTModel(result)
            "recognizeSTT" -> handleRecognizeSTT(call, result)

            // TTS Methods
            "loadTTSModel" -> handleLoadTTSModel(call, result)
            "unloadTTSModel" -> handleUnloadTTSModel(result)
            "synthesizeTTS" -> handleSynthesizeTTS(call, result)

            // LLM Methods
            "loadLLMModel" -> handleLoadLLMModel(call, result)
            "unloadLLMModel" -> handleUnloadLLMModel(result)
            "chatLLM" -> handleChatLLM(call, result)
            "chatLLMStream" -> handleChatLLMStream(call, result)
            "prepareBundledAsset" -> handlePrepareBundledAsset(call, result)

            else -> result.notImplemented()
        }
    }

    // ============================================================
    // Embedding Methods (BGE)
    // ============================================================

    private fun handleLoadEmbeddingModel(call: MethodCall, result: Result) {
        val modelPath = call.argument<String>("modelPath")
        if (modelPath == null) {
            result.error("INVALID_ARGS", "modelPath required", null)
            return
        }

        val tokenizerPathArg = call.argument<String>("tokenizerPath")

        try {
            val env = ortEnv ?: throw Exception("ONNX Environment not initialized")

            val sessionOptions = SessionOptions()
            sessionOptions.setIntraOpNumThreads(4)
            sessionOptions.setInterOpNumThreads(4)

            // Try to enable NNAPI provider for better performance on Android
            try {
                sessionOptions.addNnapi()
                android.util.Log.i("ModelLoader", "NNAPI provider enabled")
            } catch (e: Exception) {
                android.util.Log.w("ModelLoader", "NNAPI not available: ${e.message}")
            }

            embeddingSession = env.createSession(modelPath, sessionOptions)

            // Load tokenizer if provided
            if (tokenizerPathArg != null) {
                tokenizer = AndroidWordPieceTokenizer()
                tokenizer?.loadVocabulary(tokenizerPathArg)
            }

            android.util.Log.i("ModelLoader", "Embedding model loaded: $modelPath")
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Failed to load embedding model: ${e.message}")
            result.error("LOAD_ERROR", "Failed to load embedding model", null)
        }
    }

    private fun handleUnloadEmbeddingModel(result: Result) {
        try {
            embeddingSession?.close()
            embeddingSession = null
            tokenizer = null
            result.success(true)
        } catch (e: Exception) {
            result.error("UNLOAD_ERROR", "Failed to unload embedding model", null)
        }
    }

    private fun handleGetEmbedding(call: MethodCall, result: Result) {
        val session = embeddingSession
        val env = ortEnv
        if (session == null) {
            result.error("NOT_LOADED", "Embedding model not loaded", null)
            return
        }
        if (env == null) {
            result.error("NOT_INITIALIZED", "ONNX Environment not initialized", null)
            return
        }

        val text = call.argument<String>("text")
        if (text == null) {
            result.error("INVALID_ARGS", "text required", null)
            return
        }

        scope.launch {
            try {
                // Tokenize input text
                val inputIds: LongArray
                val tokenizer = this@ModelLoaderPlugin.tokenizer
                if (tokenizer != null) {
                    val ids = tokenizer.encode(text)
                    // Truncate to max length
                    val truncatedIds = ids.take(512)
                    inputIds = truncatedIds.map { it.toLong() }.toLongArray()
                    android.util.Log.i("ModelLoader", "Tokenized: ${inputIds.take(10).joinToString()}...")
                } else {
                    // Fallback to simple tokenization
                    val simpleIds = text.take(512).map { it.code.toLong() }.toLongArray()
                    inputIds = simpleIds
                }

                val inputShape = longArrayOf(1, inputIds.size.toLong())
                val attentionMask = LongArray(inputIds.size) { 1L }
                val tokenTypeIds = LongArray(inputIds.size) { 0L }

                fun createLongTensor(values: LongArray): OnnxTensor {
                    return OnnxTensor.createTensor(
                        env,
                        java.nio.LongBuffer.wrap(values),
                        inputShape,
                    )
                }

                // Build model inputs by name for transformer compatibility
                val inputMap = mutableMapOf<String, OnnxTensor>()
                val allocatedTensors = mutableListOf<OnnxTensor>()
                val embedding = try {
                    for (inputName in session.inputNames) {
                        val lower = inputName.lowercase()
                        val tensor = when {
                            lower.contains("attention_mask") -> createLongTensor(attentionMask)
                            lower.contains("token_type") || lower.contains("segment") -> createLongTensor(tokenTypeIds)
                            else -> createLongTensor(inputIds)
                        }
                        inputMap[inputName] = tensor
                        allocatedTensors.add(tensor)
                    }

                    android.util.Log.d("ModelLoader", "Running inference with input shape: [1, ${inputIds.size}]")

                    val outputResult = session.run(inputMap)
                    try {
                        val outputName = session.outputNames.first()
                        val outputValue = outputResult.get(outputName).get()
                        extractEmbeddingFromValue(outputValue)
                    } finally {
                        outputResult.close()
                    }
                } finally {
                    allocatedTensors.forEach { it.close() }
                }

                android.util.Log.i("ModelLoader", "Embedding extracted, dimension: ${embedding.size}")

                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "embedding" to embedding,
                        "dimension" to embedding.size
                    ))
                }
            } catch (e: Exception) {
                android.util.Log.e("ModelLoader", "Embedding inference error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("INFERENCE_ERROR", e.message, null)
                }
            }
        }
    }

    // ============================================================
    // OCR Methods
    // ============================================================

    private fun handleLoadOCRModel(call: MethodCall, result: Result) {
        val modelPath = call.argument<String>("modelPath")
        if (modelPath == null) {
            result.error("INVALID_ARGS", "modelPath required", null)
            return
        }

        try {
            val env = ortEnv ?: throw Exception("ONNX Environment not initialized")

            val sessionOptions = SessionOptions()
            sessionOptions.setIntraOpNumThreads(4)
            sessionOptions.setInterOpNumThreads(4)

            // Disable optimization for PaddleOCR models that have shape inference issues
            // The model has Concat nodes where scalar (rank 0) and 1D (rank 1) inputs coexist
            try {
                sessionOptions.setOptimizationLevel(SessionOptions.OptLevel.NO_OPT)
                android.util.Log.i("ModelLoader", "OCR: Optimization disabled to avoid shape inference error")
            } catch (e: Exception) {
                android.util.Log.w("ModelLoader", "Could not set optimization level: ${e.message}")
            }

            // Try to enable NNAPI provider for better performance on Android
            try {
                sessionOptions.addNnapi()
            } catch (e: Exception) {
                android.util.Log.w("ModelLoader", "NNAPI not available: ${e.message}")
            }

            ocrSession = env.createSession(modelPath, sessionOptions)
            android.util.Log.i("ModelLoader", "OCR model loaded: $modelPath")
            loadOcrCharDict(applicationContext)
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Failed to load OCR model: ${e.message}")
            result.error("LOAD_ERROR", "Failed to load OCR model", null)
        }
    }

    private fun handleUnloadOCRModel(result: Result) {
        try {
            ocrSession?.close()
            ocrSession = null
            result.success(true)
        } catch (e: Exception) {
            result.error("UNLOAD_ERROR", "Failed to unload OCR model", null)
        }
    }

    private fun handleRecognizeOCR(call: MethodCall, result: Result) {
        val session = ocrSession
        val env = ortEnv
        if (session == null) {
            result.error("NOT_LOADED", "OCR model not loaded", null)
            return
        }
        if (env == null) {
            result.error("NOT_INITIALIZED", "ONNX Environment not initialized", null)
            return
        }

        val imageData = call.argument<ByteArray>("imageData")
        if (imageData == null) {
            result.error("INVALID_ARGS", "imageData required", null)
            return
        }

        scope.launch {
            try {
                val bitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.size)
                if (bitmap == null) {
                    withContext(Dispatchers.Main) {
                        result.error("IMAGE_ERROR", "Failed to decode image", null)
                    }
                    return@launch
                }

                // PaddleOCR PP-OCRv4 rec: input [1, 3, 48, 320], RGB normalized to [-1, 1]
                val inputHeight = 48
                val inputWidth = 320
                val scaledBitmap = Bitmap.createScaledBitmap(bitmap, inputWidth, inputHeight, true)
                // createScaledBitmap returns the same object if dimensions match
                val needsSeparateRecycle = scaledBitmap !== bitmap

                // Detect inverted images (white text on dark background) and auto-invert
                val processedBitmap = detectAndFixInversion(scaledBitmap)
                val needsRecycleProcessed = processedBitmap !== scaledBitmap

                val floatBuffer = bitmapToRgbFloatBuffer(processedBitmap, mean = floatArrayOf(0.5f, 0.5f, 0.5f), std = floatArrayOf(0.5f, 0.5f, 0.5f))

                val inputName = session.inputNames.first()
                val tensor = OnnxTensor.createTensor(env, floatBuffer, longArrayOf(1, 3, inputHeight.toLong(), inputWidth.toLong()))

                val output = session.run(mapOf(inputName to tensor))
                val outputTensor = output.first().value
                val outputArray = outputTensor.value as Array<Array<FloatArray>>

                android.util.Log.d("ModelLoader", "OCR output: seqLen=${outputArray[0].size}, vocab=${outputArray[0][0].size}")

                val text = ctcGreedyDecode(outputArray[0])

                // Model output is already softmax probabilities (last node is Softmax).
                // The max value per timestep IS the confidence — no extra softmax needed.
                var totalConf = 0.0
                var charCount = 0
                for ((tIdx, row) in outputArray[0].withIndex()) {
                    // Find argmax
                    var maxIdx = 0
                    var maxVal = row[0]
                    for (i in 1 until row.size) {
                        if (row[i] > maxVal) { maxVal = row[i]; maxIdx = i }
                    }
                    // Skip blank timesteps (index 0)
                    if (maxIdx == 0) continue

                    // maxVal is already the softmax probability of the predicted class
                    totalConf += maxVal.toDouble()
                    charCount++

                    if (tIdx < 5) {
                        android.util.Log.d("ModelLoader", "OCR conf t=$tIdx idx=$maxIdx prob=${String.format("%.4f", maxVal)}")
                    }
                }
                val confidence = if (charCount > 0) totalConf / charCount else 0.0
                android.util.Log.d("ModelLoader", "OCR conf total=${String.format("%.4f", totalConf)} charCount=$charCount avg=${String.format("%.4f", confidence)}")

                tensor.close()
                output.close()
                if (needsRecycleProcessed) processedBitmap.recycle()
                if (needsSeparateRecycle) scaledBitmap.recycle()
                bitmap.recycle()

                android.util.Log.i("ModelLoader", "OCR result: '$text' (conf=${String.format("%.2f", confidence)})")

                withContext(Dispatchers.Main) {
                    result.success(mapOf("text" to text, "confidence" to confidence))
                }
            } catch (e: Exception) {
                android.util.Log.e("ModelLoader", "OCR inference error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("INFERENCE_ERROR", e.message, null)
                }
            }
        }
    }

    /**
     * Detect if image is inverted (white text on dark background).
     * PaddleOCR expects dark text on white background.
     * If average brightness is low, invert the image.
     */
    private fun detectAndFixInversion(bitmap: Bitmap): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)

        var totalBrightness = 0L
        for (pixel in pixels) {
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            totalBrightness += (r + g + b) / 3
        }
        val avgBrightness = totalBrightness / pixels.size

        // If average brightness < 128, image is likely inverted
        if (avgBrightness < 128) {
            android.util.Log.d("ModelLoader", "OCR: detected inverted image (avg brightness=$avgBrightness), inverting...")
            val inverted = Bitmap.createBitmap(w, h, bitmap.config ?: Bitmap.Config.ARGB_8888)
            for (i in pixels.indices) {
                val pixel = pixels[i]
                val a = (pixel shr 24) and 0xFF
                val r = 255 - ((pixel shr 16) and 0xFF)
                val g = 255 - ((pixel shr 8) and 0xFF)
                val b = 255 - (pixel and 0xFF)
                pixels[i] = (a shl 24) or (r shl 16) or (g shl 8) or b
            }
            inverted.setPixels(pixels, 0, w, 0, 0, w, h)
            return inverted
        }
        return bitmap
    }

    /**
     * Convert Bitmap to NCHW RGB float buffer with normalization.
     * Pixel = (pixel / 255.0 - mean) / std
     */
    private fun bitmapToRgbFloatBuffer(bitmap: Bitmap, mean: FloatArray, std: FloatArray): java.nio.FloatBuffer {
        val width = bitmap.width
        val height = bitmap.height
        val buffer = java.nio.FloatBuffer.allocate(1 * 3 * height * width)
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        // CHW layout: R plane, G plane, B plane
        val rPlane = FloatArray(height * width)
        val gPlane = FloatArray(height * width)
        val bPlane = FloatArray(height * width)

        for (i in pixels.indices) {
            val pixel = pixels[i]
            // RGB channel order - extracted from ARGB format
            rPlane[i] = (((pixel shr 16 and 0xFF) / 255.0f) - mean[0]) / std[0]
            gPlane[i] = (((pixel shr 8 and 0xFF) / 255.0f) - mean[1]) / std[1]
            bPlane[i] = (((pixel and 0xFF) / 255.0f) - mean[2]) / std[2]
        }

        buffer.put(rPlane)
        buffer.put(gPlane)
        buffer.put(bPlane)
        buffer.rewind()
        return buffer
    }

    /**
     * CTC greedy decode: argmax per timestep, collapse repeated chars, remove blank (index 0).
     */
    private fun ctcGreedyDecode(logits: Array<FloatArray>): String {
        val sb = StringBuilder()
        var lastIdx = -1
        for (timestep in logits) {
            var maxIdx = 0
            var maxVal = timestep[0]
            for (i in 1 until timestep.size) {
                if (timestep[i] > maxVal) {
                    maxVal = timestep[i]
                    maxIdx = i
                }
            }
            if (maxIdx != 0 && maxIdx != lastIdx) {
                // Map index to character: index 1 = first char in dictionary (index 0 is blank)
                val charIdx = maxIdx - 1
                val ch = ocrCharDict.getOrElse(charIdx) { '?' }
                sb.append(ch)
            }
            lastIdx = maxIdx
        }
        return sb.toString()
    }

    /** Character dictionary loaded from ppocr_keys_v1.txt */
    private var ocrCharDict: List<String> = emptyList()

    private fun loadOcrCharDict(context: Context) {
        try {
            val lines = context.assets.open("flutter_assets/assets/models/ocr/ppocr_keys_v1.txt")
                .bufferedReader().readLines()
            ocrCharDict = lines.filter { it.isNotEmpty() }
            android.util.Log.i("ModelLoader", "OCR char dict loaded: ${ocrCharDict.size} chars")
        } catch (e: Exception) {
            android.util.Log.w("ModelLoader", "Failed to load OCR char dict: ${e.message}")
            ocrCharDict = emptyList()
        }
    }

    // ============================================================
    // STT Methods
    // ============================================================

    private fun handleLoadSTTModel(call: MethodCall, result: Result) {
        val modelPath = call.argument<String>("modelPath")
        if (modelPath == null) {
            result.error("INVALID_ARGS", "modelPath required", null)
            return
        }

        try {
            val env = ortEnv ?: throw Exception("ONNX Environment not initialized")

            val sessionOptions = SessionOptions()
            sessionOptions.setIntraOpNumThreads(4)
            sessionOptions.setInterOpNumThreads(4)

            // Try to enable NNAPI provider for better performance on Android
            try {
                sessionOptions.addNnapi()
            } catch (e: Exception) {
                android.util.Log.w("ModelLoader", "NNAPI not available: ${e.message}")
            }

            // Resolve encoder and decoder model paths
            val modelDir = File(modelPath).parentFile?.canonicalPath ?: ""
            val encoderPath = "$modelDir/onnx/encoder_model.onnx"
            val decoderPath = "$modelDir/onnx/decoder_model_merged.onnx"

            android.util.Log.i("ModelLoader", "Loading STT encoder from: $encoderPath")
            sttEncoderSession = env.createSession(encoderPath, sessionOptions)
            android.util.Log.i("ModelLoader", "STT encoder model loaded")

            android.util.Log.i("ModelLoader", "Loading STT decoder from: $decoderPath")
            sttDecoderSession = env.createSession(decoderPath, sessionOptions)
            android.util.Log.i("ModelLoader", "STT decoder model loaded")

            // Load vocabulary for token decoding
            loadSTTVocabulary(modelDir)

            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Failed to load STT model: ${e.message}", e)
            result.error("LOAD_ERROR", "Failed to load STT model: ${e.message}", null)
        }
    }

    private fun loadSTTVocabulary(modelDir: String) {
        try {
            val vocabFile = File(modelDir, "vocab.json")
            if (vocabFile.exists()) {
                val json = vocabFile.readText()
                val mapType = object : TypeToken<Map<String, Int>>() {}.type
                val vocabMap: Map<String, Int> = Gson().fromJson(json, mapType)
                // Invert: token ID -> token text
                sttVocab = vocabMap.entries.associate { it.value to it.key }
                android.util.Log.i("ModelLoader", "STT vocab loaded: ${sttVocab?.size} tokens")
            }

            val addedTokensFile = File(modelDir, "added_tokens.json")
            if (addedTokensFile.exists()) {
                val json = addedTokensFile.readText()
                val mapType = object : TypeToken<Map<String, Int>>() {}.type
                sttAddedTokens = Gson().fromJson(json, mapType)
                android.util.Log.i("ModelLoader", "STT added tokens loaded: ${sttAddedTokens?.size} tokens")
            }
        } catch (e: Exception) {
            android.util.Log.w("ModelLoader", "Failed to load STT vocabulary: ${e.message}")
        }
    }

    private fun handleUnloadSTTModel(result: Result) {
        try {
            sttEncoderSession?.close()
            sttEncoderSession = null
            sttDecoderSession?.close()
            sttDecoderSession = null
            sttVocab = null
            sttAddedTokens = null
            result.success(true)
        } catch (e: Exception) {
            result.error("UNLOAD_ERROR", "Failed to unload STT model", null)
        }
    }

    private fun handleRecognizeSTT(call: MethodCall, result: Result) {
        val encoderSession = sttEncoderSession
        val decoderSession = sttDecoderSession
        val env = ortEnv
        if (encoderSession == null || decoderSession == null) {
            result.error("NOT_LOADED", "STT model not loaded", null)
            return
        }
        if (env == null) {
            result.error("NOT_INITIALIZED", "ONNX Environment not initialized", null)
            return
        }

        val audioData = call.argument<ByteArray>("audioData")
        if (audioData == null) {
            result.error("INVALID_ARGS", "audioData required", null)
            return
        }

        // Validate minimum audio length (at least 100 bytes = 50 samples of 16-bit PCM)
        if (audioData.size < 100) {
            result.error("INVALID_ARGS", "audioData too short (minimum 100 bytes for meaningful audio)", null)
            return
        }

        scope.launch {
            try {
                // Convert audio to float array (assumes 16-bit PCM, 16kHz, mono)
                val floatData = convertAudioToFloat(audioData)

                // Generate log-mel spectrogram
                android.util.Log.d("ModelLoader", "STT: Converting audio to mel spectrogram, ${floatData.size} samples")
                val melSpectrogram = computeLogMelSpectrogram(floatData)
                android.util.Log.d("ModelLoader", "STT: Mel spectrogram shape: ${melSpectrogram.size}x${melSpectrogram[0].size}")

                // Run encoder inference
                android.util.Log.d("ModelLoader", "STT: Running encoder inference")
                val encoderOutput = runEncoderInference(encoderSession, env, melSpectrogram)
                android.util.Log.d("ModelLoader", "STT: Encoder output shape: ${encoderOutput.size}")

                // Run decoder inference (autoregressive)
                android.util.Log.d("ModelLoader", "STT: Running decoder inference")
                val tokens = runDecoderInference(decoderSession, env, encoderOutput)
                android.util.Log.d("ModelLoader", "STT: Generated ${tokens.size} tokens")

                // Decode tokens to text
                val text = decodeTokens(tokens)
                val confidence = decoderConfidence

                android.util.Log.i("ModelLoader", "STT result: '$text' (conf=$confidence, tokens=${tokens.size})")

                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "text" to text,
                        "confidence" to confidence,
                        "language" to "auto"
                    ))
                }
            } catch (e: Exception) {
                android.util.Log.e("ModelLoader", "STT inference error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("INFERENCE_ERROR", e.message, null)
                }
            }
        }
    }

    // ============================================================
    // Whisper STT Implementation
    // ============================================================

    // Whisper audio parameters
    private val SAMPLE_RATE = 16000
    private val HOP_LENGTH = 160  // 10ms at 16kHz
    private val WIN_LENGTH = 400  // 25ms at 16kHz
    private val N_FFT = 512
    private val N_MELS = 80
    private val F_MIN = 0.0
    private val F_MAX = 8000.0
    private val MAX_AUDIO_LENGTH = 480000  // 30 seconds at 16kHz

    // Whisper token IDs for special tokens
    private val TOKEN_NO_TIMESTAMPS = 50363  // <|notimestamps|>
    private val TOKEN_TRANSCRIBE = 50359  // <|transcribe|>
    private val TOKEN_TRANSLATE = 50358  // <|translate|>
    private val TOKEN_START_OF_TRANSCRIPT = 50258  // <|startoftranscript|>
    private val TOKEN_END_OF_TRANSCRIPT = 50257  // <|endoftext|>
    private val TOKEN_TIMESTAMP_BEGIN = 50364  // <|0.00|>

    /**
     * Compute log-mel spectrogram from audio float samples
     * Output shape: [n_mels, n_frames] = [80, 3000] for 30s audio
     */
    private fun computeLogMelSpectrogram(audioFloat: FloatArray): Array<FloatArray> {
        // Pad or trim audio to exactly MAX_AUDIO_LENGTH
        val audio = if (audioFloat.size < MAX_AUDIO_LENGTH) {
            audioFloat.copyOf(MAX_AUDIO_LENGTH)
        } else if (audioFloat.size > MAX_AUDIO_LENGTH) {
            audioFloat.copyOf(MAX_AUDIO_LENGTH)
        } else {
            audioFloat
        }

        // Pre-emphasis filter (optional, skipped for simplicity)
        // Build Hann window
        val window = FloatArray(WIN_LENGTH) { i ->
            (0.5 * (1 - cos(2 * PI * i / (WIN_LENGTH - 1)))).toFloat()
        }

        // Number of frames
        val nFrames = (audio.size - WIN_LENGTH) / HOP_LENGTH + 1

        // Mel filterbank (computed once)
        val melFilterbank = computeMelFilterbank()

        // Compute spectrogram for each frame
        val spectrogram = Array(N_MELS) { FloatArray(nFrames) }

        // Temporary buffers for FFT
        val fftReal = FloatArray(N_FFT)
        val fftImag = FloatArray(N_FFT)
        val realOut = FloatArray(N_FFT / 2 + 1)
        val imagOut = FloatArray(N_FFT / 2 + 1)

        for (frameIdx in 0 until nFrames) {
            val start = frameIdx * HOP_LENGTH

            // Apply window and copy to FFT buffer
            for (i in 0 until WIN_LENGTH) {
                fftReal[i] = audio[start + i] * window[i]
            }
            // Zero-pad to N_FFT
            for (i in WIN_LENGTH until N_FFT) {
                fftReal[i] = 0f
            }
            // Initialize imaginary to 0
            for (i in 0 until N_FFT) {
                fftImag[i] = 0f
            }

            // Radix-2 FFT
            fft(fftReal, fftImag, realOut, imagOut)

            // Compute power spectrum (magnitude squared)
            val power = FloatArray(N_FFT / 2 + 1)
            for (i in 0..N_FFT / 2) {
                power[i] = realOut[i] * realOut[i] + imagOut[i] * imagOut[i]
            }

            // Apply mel filterbank and compute mel spectrogram
            for (m in 0 until N_MELS) {
                var sum = 0f
                for (k in 0 until N_FFT / 2 + 1) {
                    sum += power[k] * melFilterbank[m][k]
                }
                // Log mel spectrogram (with floor to avoid log(0))
                spectrogram[m][frameIdx] = if (sum > 1e-10f) log10(max(sum, 1e-10f)).toFloat() else -10f
            }
        }

        // Transpose to [n_mels, n_frames] format for ONNX
        val result = Array(N_MELS) { FloatArray(nFrames) }
        for (m in 0 until N_MELS) {
            for (t in 0 until nFrames) {
                result[m][t] = spectrogram[m][t]
            }
        }

        return result
    }

    /**
     * Radix-2 Cooley-Tukey FFT for complex input
     * inputReal and inputImag are the real and imaginary parts (in-place on real part only for simplicity)
     * Output: magnitude spectrum
     */
    private fun fft(inputReal: FloatArray, inputImag: FloatArray, realOut: FloatArray, imagOut: FloatArray) {
        val n = inputReal.size

        // Bit-reversal permutation for both real and imag
        val bits = (log2(n.toDouble())).toInt()
        val rev = IntArray(n)
        for (i in 0 until n) {
            rev[i] = Integer.reverse(i).ushr(32 - bits)
        }

        for (i in 0 until n) {
            val j = rev[i]
            if (i < j) {
                // Swap real parts
                var temp = inputReal[i]
                inputReal[i] = inputReal[j]
                inputReal[j] = temp
                // Swap imaginary parts
                temp = inputImag[i]
                inputImag[i] = inputImag[j]
                inputImag[j] = temp
            }
        }

        // Cooley-Tukey iterative FFT
        var size = 2
        while (size <= n) {
            val halfSize = size / 2
            val angleStep = -2.0 * PI / size

            for (i in 0 until n step size) {
                for (j in 0 until halfSize) {
                    val angle = angleStep * j
                    val wReal = cos(angle).toFloat()
                    val wImag = sin(angle).toFloat()

                    val idx1 = i + j
                    val idx2 = idx1 + halfSize

                    val uReal = inputReal[idx1]
                    val uImag = inputImag[idx1]
                    val vReal = inputReal[idx2]
                    val vImag = inputImag[idx2]

                    // Butterfly: u + v*w
                    val vWReal = vReal * wReal - vImag * wImag
                    val vWImag = vReal * wImag + vImag * wReal

                    inputReal[idx1] = uReal + vWReal
                    inputImag[idx1] = uImag + vWImag
                    inputReal[idx2] = uReal - vWReal
                    inputImag[idx2] = uImag - vWImag
                }
            }
            size *= 2
        }

        // Copy to output (only first N_FFT/2+1 bins needed for power spectrum)
        val outSize = N_FFT / 2 + 1
        for (i in 0 until outSize) {
            realOut[i] = inputReal[i]
            imagOut[i] = inputImag[i]
        }
    }

    private fun log2(x: Double): Double = ln(x) / ln(2.0)
    private fun ln(x: Double): Double = kotlin.math.ln(x)

    /**
     * Compute mel filterbank
     */
    private fun computeMelFilterbank(): Array<FloatArray> {
        // Convert mel and frequency scales
        fun hzToMel(hz: Double): Double = 2595 * log10(1 + hz / 700)
        fun melToHz(mel: Double): Double = 700 * (10.0.pow(mel / 2595) - 1)

        // Frequency bins
        val lowFreqMel = hzToMel(F_MIN)
        val highFreqMel = hzToMel(F_MAX)

        // Create n_mels + 2 points on mel scale
        val melPoints = DoubleArray(N_MELS + 2) { i ->
            lowFreqMel + (highFreqMel - lowFreqMel) * i / (N_MELS + 1)
        }

        // Convert to Hz
        val hzPoints = DoubleArray(N_MELS + 2) { i ->
            melToHz(melPoints[i])
        }

        // Convert to FFT bin indices
        val binPoints = IntArray(N_MELS + 2) { i ->
            floor((N_FFT + 1) * hzPoints[i] / SAMPLE_RATE).toInt()
        }

        // Build filterbank
        val filterbank = Array(N_MELS) { FloatArray(N_FFT / 2 + 1) }

        for (m in 1 until N_MELS + 1) {
            val left = binPoints[m - 1]
            val center = binPoints[m]
            val right = binPoints[m + 1]

            for (k in left until center) {
                filterbank[m - 1][k] = ((k - left).toFloat() / (center - left)).coerceIn(0f, 1f)
            }
            for (k in center until right) {
                filterbank[m - 1][k] = ((right - k).toFloat() / (right - center)).coerceIn(0f, 1f)
            }
        }

        return filterbank
    }

    /**
     * Run encoder ONNX inference
     * Input: [1, 80, 3000] log-mel spectrogram
     * Output: [1, 1500, 384] encoder hidden states
     */
    private fun runEncoderInference(session: OrtSession, env: OrtEnvironment, melSpectrogram: Array<FloatArray>): Array<Array<Float>> {
        // melSpectrogram is [80, n_frames], need [1, 80, 3000]
        val nMels = melSpectrogram.size
        val nFrames = melSpectrogram[0].size
        val targetFrames = 3000  // Whisper expects exactly 3000 frames (30s audio)

        // Pad or truncate to targetFrames
        val actualFrames = minOf(nFrames, targetFrames)
        val inputFloat = FloatArray(1 * nMels * targetFrames)
        for (m in 0 until nMels) {
            for (t in 0 until actualFrames) {
                inputFloat[m * targetFrames + t] = melSpectrogram[m][t]
            }
            // Remaining frames are zero-padded (already initialized to 0)
        }

        val inputShape = longArrayOf(1, nMels.toLong(), targetFrames.toLong())
        val inputBuffer = java.nio.FloatBuffer.wrap(inputFloat)
        val inputTensor = OnnxTensor.createTensor(env, inputBuffer, inputShape)

        val inputs = mapOf("input_features" to inputTensor)

        android.util.Log.d("ModelLoader", "STT encoder input shape: [1, $nMels, $nFrames]")

        val outputs = session.run(inputs)
        val outputValue = outputs.get(0)

        // Extract output [1, 1500, 384]
        val outputTensor = (outputValue as? OnnxTensor)
            ?: throw Exception("Encoder output is not a tensor")

        val outputShape = outputTensor.info.shape
        val outputData = outputTensor.floatBuffer.array()

        android.util.Log.d("ModelLoader", "STT encoder output shape: ${outputShape.contentToString()}")

        // Reshape to [1500, 384]
        val encoderSeqLen = outputShape[1].toInt()
        val hiddenDim = outputShape[2].toInt()
        val result = Array(encoderSeqLen) { Array(hiddenDim) { 0f } }

        for (i in 0 until encoderSeqLen) {
            for (j in 0 until hiddenDim) {
                result[i][j] = outputData[i * hiddenDim + j]
            }
        }

        inputTensor.close()
        outputs.close()

        return result
    }

    /**
     * Run decoder ONNX inference (autoregressive)
     * Uses KV cache for efficient generation
     */
    private var decoderConfidence: Double = 0.0

    private fun runDecoderInference(session: OrtSession, env: OrtEnvironment, encoderOutput: Array<Array<Float>>): List<Int> {
        val maxLength = 448  // Maximum tokens to generate
        val eosToken = TOKEN_END_OF_TRANSCRIPT

        // Prepare encoder hidden states tensor [1, 1500, 384]
        val encoderSeqLen = encoderOutput.size
        val hiddenDim = encoderOutput[0].size
        val encoderFloat = FloatArray(encoderSeqLen * hiddenDim)
        for (i in 0 until encoderSeqLen) {
            for (j in 0 until hiddenDim) {
                encoderFloat[i * hiddenDim + j] = encoderOutput[i][j]
            }
        }
        val encoderShape = longArrayOf(1, encoderSeqLen.toLong(), hiddenDim.toLong())
        val encoderBuffer = java.nio.FloatBuffer.wrap(encoderFloat)
        val encoderTensor = OnnxTensor.createTensor(env, encoderBuffer, encoderShape)

        // Initial prompt tokens: <|startoftranscript|><|transcribe|><|nocaptions|>
        val initialTokens = listOf(TOKEN_START_OF_TRANSCRIPT, TOKEN_TRANSCRIBE, TOKEN_NO_TIMESTAMPS)

        // KV cache state: maps input name -> OnnxTensor for past_key_values
        val kvCacheInputs = mutableMapOf<String, OnnxTensor>()

        val generatedTokens = mutableListOf<Int>()
        generatedTokens.addAll(initialTokens)

        // Infer vocab size from model output shape
        var vocabSize = 51865  // fallback default

        for (step in 0 until maxLength) {
            val currentTokens = if (step == 0) {
                // First step: use initial tokens
                initialTokens.toIntArray()
            } else {
                // Subsequent steps: use only the last token
                intArrayOf(generatedTokens.last())
            }

            val seqLen = currentTokens.size

            // Create input_ids tensor [1, seqLen]
            val inputIds = LongArray(seqLen) { currentTokens[it].toLong() }
            val inputIdsShape = longArrayOf(1, seqLen.toLong())
            val inputIdsBuffer = java.nio.LongBuffer.wrap(inputIds)
            val inputIdsTensor = OnnxTensor.createTensor(env, inputIdsBuffer, inputIdsShape)

            // use_cache_branch: false for first pass (no KV cache), true for subsequent
            val useCacheValue = if (step > 0) 1.toByte() else 0.toByte()
            val useCacheShape = longArrayOf(1)
            val useCacheBuffer = java.nio.ByteBuffer.wrap(byteArrayOf(useCacheValue))
            val useCacheTensor = OnnxTensor.createTensor(env, useCacheBuffer, useCacheShape, ai.onnxruntime.OnnxJavaType.BOOL)

            // Build inputs
            val inputs: MutableMap<String, OnnxTensor> = mutableMapOf(
                "input_ids" to inputIdsTensor,
                "encoder_hidden_states" to encoderTensor,
                "use_cache_branch" to useCacheTensor
            )

            // Add KV cache inputs for subsequent steps
            for ((key, valueTensor) in kvCacheInputs) {
                inputs[key] = valueTensor
            }

            val outputs = session.run(inputs)

            // Extract logits (first output)
            val logitsOutput = outputs.get(0)
            val logitsTensor = (logitsOutput as? OnnxTensor)
                ?: throw Exception("Decoder output[0] is not a tensor")

            val logitsShape = logitsTensor.info.shape
            val logitsData = logitsTensor.floatBuffer.array()

            // Infer vocab size from model output shape
            if (logitsShape.size >= 3) {
                vocabSize = logitsShape[2].toInt()
            }

            // Get logits for last token
            val lastTokenIdx = seqLen - 1
            val logitsOffset = lastTokenIdx * vocabSize

            // Find argmax token and compute confidence from softmax
            // First find max logit for numerical stability
            var maxLogit = logitsData[logitsOffset]
            for (i in 1 until vocabSize) {
                if (logitsData[logitsOffset + i] > maxLogit) {
                    maxLogit = logitsData[logitsOffset + i]
                }
            }
            // Compute softmax sum and find argmax
            var expSum = 0.0
            var maxToken = 0
            var maxExp = 0.0
            for (i in 0 until vocabSize) {
                val expVal = exp((logitsData[logitsOffset + i] - maxLogit).toDouble())
                expSum += expVal
                if (expVal > maxExp) {
                    maxExp = expVal
                    maxToken = i
                }
            }
            val tokenConfidence = (maxExp / expSum).toFloat()
            // Update running confidence (average of per-token confidences)
            decoderConfidence = if (step == 0) tokenConfidence.toDouble()
                else (decoderConfidence * generatedTokens.size + tokenConfidence) / (generatedTokens.size + 1)

            // Capture KV cache outputs (present.key, present.value) for next step
            // Close old KV cache tensors first
            for ((_, t) in kvCacheInputs) { t.close() }
            kvCacheInputs.clear()

            // The decoder outputs logits at index 0, then present.0.key, present.0.value, ...
            // Feed them back as past_key_values.0.key, past_key_values.0.value, ...
            for (outIdx in 1 until outputs.size()) {
                val outName = outputs.get(outIdx - 1).toString()  // may not have names
                val presentTensor = outputs.get(outIdx) as? OnnxTensor ?: continue
                // Map present.N.key -> past_key_values.N.key, present.N.value -> past_key_values.N.value
                val presentName = "present.${outIdx - 1}"
                val pastName = "past_key_values.${outIdx - 1}"
                // We need to clone the tensor data since outputs will be closed
                val shape = presentTensor.info.shape
                val data = presentTensor.floatBuffer.array().copyOf()
                val buf = java.nio.FloatBuffer.wrap(data)
                val newTensor = OnnxTensor.createTensor(env, buf, shape)
                kvCacheInputs[pastName] = newTensor
            }

            // Check for EOS
            if (maxToken == eosToken) {
                android.util.Log.d("ModelLoader", "STT: EOS token generated at step $step")
                inputIdsTensor.close()
                useCacheTensor.close()
                outputs.close()
                break
            }

            generatedTokens.add(maxToken)
            android.util.Log.v("ModelLoader", "STT: Generated token $maxToken at step $step")

            // Cleanup per-step tensors (KV cache tensors moved to kvCacheInputs)
            inputIdsTensor.close()
            useCacheTensor.close()
            outputs.close()
        }

        // Cleanup KV cache
        for ((_, t) in kvCacheInputs) { t.close() }
        encoderTensor.close()

        return generatedTokens
    }

    /**
     * Decode token IDs to text using vocabulary
     */
    private fun decodeTokens(tokens: List<Int>): String {
        val vocab = sttVocab
        if (vocab == null) {
            android.util.Log.w("ModelLoader", "STT: No vocabulary loaded, returning raw tokens")
            return tokens.joinToString(" ")
        }

        val addedTokens = sttAddedTokens ?: emptyMap()

        // Special tokens to skip
        val skipTokens = setOf(
            TOKEN_START_OF_TRANSCRIPT,
            TOKEN_END_OF_TRANSCRIPT,
            TOKEN_TRANSCRIBE,
            TOKEN_TRANSLATE,
            TOKEN_NO_TIMESTAMPS,
            TOKEN_TIMESTAMP_BEGIN
        )

        val result = StringBuilder()

        for (tokenId in tokens) {
            if (tokenId in skipTokens) continue

            // Check if it's a timestamp token (50364 <|0.00|> to 51864 <|30.00|>)
            if (tokenId >= TOKEN_TIMESTAMP_BEGIN && tokenId <= 51864) {
                // Timestamp token - add space if not at start
                if (result.isNotEmpty() && !result.endsWith(" ")) {
                    result.append(" ")
                }
                continue
            }

            // Regular token - look up in vocab
            val text = vocab[tokenId] ?: addedTokens.entries.find { it.value == tokenId }?.key

            if (text != null && text.isNotEmpty()) {
                // Handle special characters
                when (text) {
                    "Ġ" -> result.append(" ")  // Space
                    "Ċ" -> result.append("\n")  // Newline
                    else -> {
                        // Remove leading Ġ (word boundary marker in SentencePiece)
                        val cleanText = if (text.startsWith("Ġ")) {
                            " " + text.substring(1)
                        } else {
                            text
                        }
                        result.append(cleanText)
                    }
                }
            }
        }

        return result.toString().trim()
    }

    // ============================================================
    // Helper Methods
    // ============================================================

    /**
     * Simple character-based tokenization fallback
     */
    private fun simpleTokenize(text: String): List<Int> {
        return text.take(512).map { it.code }
    }

    /**
     * Extract embedding from output OnnxValue
     */
    private fun extractEmbeddingFromValue(outputValue: OnnxValue): List<Double> {
        return try {
            val tensor = outputValue as? ai.onnxruntime.OnnxTensor
            if (tensor != null) {
                extractEmbedding(tensor)
            } else {
                android.util.Log.w("ModelLoader", "Output is not a tensor")
                List(384) { 0.0 }
            }
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Error extracting embedding: ${e.message}")
            List(384) { 0.0 }
        }
    }

    /**
     * Extract embedding from output tensor
     * BGE model outputs [batch, seq_len, hidden_dim] - needs mean pooling
     */
    private fun extractEmbedding(outputTensor: ai.onnxruntime.OnnxTensor): List<Double> {
        return try {
            val shape = outputTensor.info.shape
            val outputData = outputTensor.floatBuffer.array()

            when (shape.size) {
                3 -> {
                    // [batch, seq_len, hidden_dim] - apply mean pooling across seq_len
                    val seqLen = shape[1].toInt()
                    val hiddenDim = shape[2].toInt()
                    android.util.Log.d("ModelLoader", "Embedding 3D output: [${shape[0]}, $seqLen, $hiddenDim]")

                    val pooled = DoubleArray(hiddenDim)
                    for (s in 0 until seqLen) {
                        for (h in 0 until hiddenDim) {
                            pooled[h] += outputData[s * hiddenDim + h].toDouble()
                        }
                    }
                    for (h in 0 until hiddenDim) {
                        pooled[h] /= seqLen.toDouble()
                    }
                    pooled.toList()
                }
                2 -> {
                    // [batch, hidden_dim] - take directly
                    val hiddenDim = shape[1].toInt()
                    android.util.Log.d("ModelLoader", "Embedding 2D output: [${shape[0]}, $hiddenDim]")
                    outputData.take(hiddenDim).map { it.toDouble() }
                }
                1 -> {
                    // [hidden_dim]
                    val hiddenDim = shape[0].toInt()
                    android.util.Log.d("ModelLoader", "Embedding 1D output: [$hiddenDim]")
                    outputData.take(hiddenDim).map { it.toDouble() }
                }
                else -> {
                    android.util.Log.w("ModelLoader", "Unexpected embedding shape: ${shape.contentToString()}")
                    val totalSize = shape.fold(1L) { acc, v -> acc * v }.toInt()
                    outputData.take(minOf(384, totalSize)).map { it.toDouble() }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Error extracting embedding: ${e.message}")
            List(384) { 0.0 }
        }
    }

    /**
     * Convert audio data to float array for STT inference
     * Supports both raw 16-bit PCM and WAV files (with RIFF header)
     */
    private fun convertAudioToFloat(audioData: ByteArray): FloatArray {
        val pcmData = if (audioData.size >= 4 &&
            audioData[0].toInt() == 0x52 && // 'R'
            audioData[1].toInt() == 0x49 && // 'I'
            audioData[2].toInt() == 0x46 && // 'F'
            audioData[3].toInt() == 0x46    // 'F'
        ) {
            // WAV file - find the 'data' chunk and skip header
            android.util.Log.d("ModelLoader", "STT: Detected WAV file, parsing header")
            extractPCMFromWAV(audioData)
        } else {
            // Raw PCM
            audioData
        }

        // Assuming 16-bit PCM audio, little-endian
        val shortArray = ShortArray(pcmData.size / 2)
        for (i in shortArray.indices) {
            val low = pcmData[i * 2].toInt() and 0xFF
            val high = pcmData[i * 2 + 1].toInt() shl 8
            shortArray[i] = (low + high).toShort()
        }
        return shortArray.map { it.toFloat() / Short.MAX_VALUE.toFloat() }.toFloatArray()
    }

    /**
     * Extract raw PCM data from a WAV file by skipping the RIFF header
     */
    private fun extractPCMFromWAV(wavData: ByteArray): ByteArray {
        // WAV format: RIFF header + fmt chunk + data chunk
        // We need to find the 'data' chunk and return only the PCM data
        var offset = 12 // Skip RIFF header (12 bytes)

        while (offset < wavData.size - 8) {
            val chunkId = String(wavData.copyOfRange(offset, offset + 4), Charsets.US_ASCII)
            val chunkSize = wavData[offset + 4].toInt() and 0xFF or
                (wavData[offset + 5].toInt() and 0xFF shl 8) or
                (wavData[offset + 6].toInt() and 0xFF shl 16) or
                (wavData[offset + 7].toInt() and 0xFF shl 24)

            if (chunkId == "data") {
                // Found data chunk - return the PCM data
                val dataStart = offset + 8
                val dataEnd = minOf(dataStart + chunkSize, wavData.size)
                return wavData.copyOfRange(dataStart, dataEnd)
            }

            offset += 8 + chunkSize
            // Word alignment (chunks are word-aligned)
            if (chunkSize % 2 != 0) offset++
        }

        android.util.Log.w("ModelLoader", "STT: WAV data chunk not found, using full buffer")
        return wavData
    }

    // ============================================================
    // TTS Methods (Android TextToSpeech)
    // ============================================================

    private fun handleLoadTTSModel(call: MethodCall, result: Result) {
        val language = call.argument<String>("language") ?: "en-US"

        try {
            if (tts == null) {
                tts = TextToSpeech(applicationContext) { status ->
                    if (status == TextToSpeech.SUCCESS) {
                        ttsInitialized = true
                        android.util.Log.i("ModelLoader", "TTS initialized successfully")
                    } else {
                        ttsInitialized = false
                        android.util.Log.e("ModelLoader", "TTS initialization failed with status: $status")
                    }
                }
            }

            // Wait a bit for initialization if not yet done
            if (!ttsInitialized) {
                Thread.sleep(500) // Give TTS engine time to initialize
            }

            val locale = when {
                language.startsWith("zh") -> Locale.SIMPLIFIED_CHINESE
                language.startsWith("ja") -> Locale.JAPANESE
                language.startsWith("ko") -> Locale.KOREAN
                language.startsWith("es") -> Locale("es", "ES")
                language.startsWith("fr") -> Locale.FRENCH
                language.startsWith("de") -> Locale.GERMAN
                else -> Locale.US
            }

            val langStatus = tts?.setLanguage(locale)
            if (langStatus == TextToSpeech.LANG_MISSING_DATA || langStatus == TextToSpeech.LANG_NOT_SUPPORTED) {
                android.util.Log.w("ModelLoader", "Language not supported: $language, falling back to US")
                tts?.setLanguage(Locale.US)
            }

            android.util.Log.i("ModelLoader", "TTS model loaded for language: $language")
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Failed to load TTS model: ${e.message}")
            result.error("LOAD_ERROR", "Failed to load TTS model: ${e.message}", null)
        }
    }

    private fun handleUnloadTTSModel(result: Result) {
        try {
            tts?.shutdown()
            tts = null
            ttsInitialized = false
            android.util.Log.i("ModelLoader", "TTS model unloaded")
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Failed to unload TTS model: ${e.message}")
            result.error("UNLOAD_ERROR", "Failed to unload TTS model: ${e.message}", null)
        }
    }

    private fun handleSynthesizeTTS(call: MethodCall, result: Result) {
        val text = call.argument<String>("text")
        if (text.isNullOrBlank()) {
            result.error("INVALID_ARGS", "text is required", null)
            return
        }

        val outputPath = call.argument<String>("outputPath")
        if (outputPath.isNullOrBlank()) {
            result.error("INVALID_ARGS", "outputPath is required", null)
            return
        }

        if (!ttsInitialized || tts == null) {
            result.error("TTS_NOT_INITIALIZED", "TTS engine not initialized", null)
            return
        }

        try {
            val javaFile = java.io.File(outputPath)

            // Set speech rate and pitch on TTS instance before synthesis
            val speed = call.argument<Double>("speed")
            if (speed != null && speed > 0) {
                tts?.setSpeechRate(speed.toFloat())
            }

            val pitch = call.argument<Double>("pitch")
            if (pitch != null && pitch > 0) {
                tts?.setPitch(pitch.toFloat())
            }

            // Bundle params for synthesizeToFile - only for utterance extras, not rate/pitch
            val params = android.os.Bundle()

            val success = tts?.synthesizeToFile(text, params, javaFile, outputPath)
            if (success == TextToSpeech.SUCCESS) {
                android.util.Log.i("ModelLoader", "TTS synthesized to: $outputPath")
                result.success(outputPath)
            } else {
                android.util.Log.e("ModelLoader", "TTS synthesizeToFile failed with code: $success")
                result.error("SYNTHESIS_ERROR", "Failed to synthesize speech, error code: $success", null)
            }
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "TTS synthesis failed: ${e.message}")
            result.error("SYNTHESIS_ERROR", "TTS synthesis failed: ${e.message}", null)
        }
    }

    // ============================================================
    // LLM Methods (native llama bridge)
    // ============================================================

    private var llmLoaded: Boolean = false

    /**
     * Load LLM model
     */
    private fun handleLoadLLMModel(call: MethodCall, result: Result) {
        if (!nativeBridgeAvailable) {
            result.error("NATIVE_UNAVAILABLE", "Native llama bridge unavailable", null)
            return
        }

        val modelPathArg = call.argument<String>("modelPath")
        if (modelPathArg.isNullOrBlank()) {
            result.error("INVALID_ARGS", "modelPath required", null)
            return
        }

        val modelPath = validateLlmModelPath(modelPathArg)
        if (modelPath == null) {
            result.error(
                "INVALID_ARGS",
                "modelPath must be a .gguf file under app cache/models directory",
                null,
            )
            return
        }

        val contextLength = clampContextLength(call.argument<Int>("contextLength") ?: 2048)
        val threads = normalizeThreads(call.argument<Int>("threads"))
        val useGpu = call.argument<Boolean>("useGpu") ?: true
        val gpuLayers = normalizeGpuLayers(call.argument<Int>("gpuLayers"), useGpu)

        try {
            if (!nativeLlamaFileExists(modelPath)) {
                result.error("LOAD_ERROR", "Model file not found", null)
                return
            }
        } catch (e: Throwable) {
            result.error("NATIVE_UNAVAILABLE", "Native llama bridge invocation failed", null)
            return
        }

        scope.launch {
            try {
                val loaded = nativeLoadLlamaModel(
                    modelPath,
                    contextLength,
                    threads,
                    gpuLayers,
                    useGpu,
                )
                llmLoaded = loaded
                withContext(Dispatchers.Main) {
                    if (loaded) {
                        result.success(true)
                    } else {
                        result.error("LOAD_ERROR", "Failed to load LLM model via JNI", null)
                    }
                }
            } catch (e: Throwable) {
                withContext(Dispatchers.Main) {
                    result.error("LOAD_ERROR", "Native llama model load failed", null)
                }
            }
        }
    }

    /**
     * Unload LLM model
     */
    private fun handleUnloadLLMModel(result: Result) {
        if (!nativeBridgeAvailable) {
            llmLoaded = false
            result.success(true)
            return
        }

        try {
            nativeUnloadLlamaModel()
            llmLoaded = false
            result.success(true)
        } catch (e: Throwable) {
            result.error("UNLOAD_ERROR", "Native llama model unload failed", null)
        }
    }

    /**
     * Chat with LLM (non-streaming)
     */
    private fun handleChatLLM(call: MethodCall, result: Result) {
        if (!nativeBridgeAvailable) {
            result.error("NATIVE_UNAVAILABLE", "Native llama bridge unavailable", null)
            return
        }

        try {
            if (!llmLoaded || !nativeIsLlamaLoaded()) {
                result.error("NOT_LOADED", "LLM model not loaded", null)
                return
            }
        } catch (e: Throwable) {
            result.error("NATIVE_UNAVAILABLE", "Native llama bridge invocation failed", null)
            return
        }

        val messages = call.argument<List<Map<String, Any>>>("messages")
        if (messages == null) {
            result.error("INVALID_ARGS", "messages required", null)
            return
        }

        val normalizedMessages = normalizeChatMessages(messages)
        if (normalizedMessages == null) {
            result.error("INVALID_ARGS", "messages must include at least one non-empty entry", null)
            return
        }

        val temperature = clampTemperature(call.argument<Double>("temperature") ?: 0.7)
        val maxTokens = clampMaxTokens(call.argument<Int>("maxTokens") ?: 2048)
        val topP = clampTopP(call.argument<Double>("topP") ?: 0.9)
        val topK = clampTopK(call.argument<Int>("topK") ?: 40)
        val repeatPenalty = clampRepeatPenalty(call.argument<Double>("repeatPenalty") ?: 1.0)
        val seed = call.argument<Int>("seed") ?: -1

        scope.launch {
            try {
                val text = nativeChatLlamaMessages(
                    normalizedMessages.roles,
                    normalizedMessages.contents,
                    maxTokens,
                    temperature,
                    topP,
                    topK,
                    repeatPenalty,
                    seed,
                )
                withContext(Dispatchers.Main) {
                    if (text.isNotEmpty()) {
                        result.success(text)
                    } else {
                        result.error("INFERENCE_FAILED", "LLM native inference returned empty output", null)
                    }
                }
            } catch (e: Throwable) {
                withContext(Dispatchers.Main) {
                    result.error("LLM_ERROR", "Native llama inference failed", null)
                }
            }
        }
    }

    private fun handleChatLLMStream(call: MethodCall, result: Result) {
        handleChatLLM(call, result)
    }

    private fun handlePrepareBundledAsset(call: MethodCall, result: Result) {
        val assetPathArg = call.argument<String>("assetPath")
        val assetPath = assetPathArg?.let(::normalizeBundledAssetPath)
        if (assetPath == null) {
            result.error("INVALID_ARGS", "assetPath required", null)
            return
        }

        try {
            result.success(stageBundledAsset(assetPath))
        } catch (e: FileNotFoundException) {
            result.error("ASSET_NOT_FOUND", "Bundled asset not found", null)
        } catch (e: SecurityException) {
            result.error("INVALID_ARGS", "Bundled asset path is invalid", null)
        } catch (e: Throwable) {
            android.util.Log.e("ModelLoader", "Failed to prepare bundled asset: ${e.message}", e)
            result.error("ASSET_PREPARE_FAILED", "Failed to prepare bundled asset", null)
        }
    }
}
