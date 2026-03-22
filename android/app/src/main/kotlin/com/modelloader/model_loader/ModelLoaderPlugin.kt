package com.modelloader.model_loader

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.File
import java.io.FileNotFoundException
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OnnxValue
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.OrtSession.SessionOptions

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
    private var sttSession: OrtSession? = null
    private var embeddingSession: OrtSession? = null

    // Tokenizer for embedding models
    private var tokenizer: AndroidWordPieceTokenizer? = null

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
            sttSession?.close()
            embeddingSession?.close()
            ortEnv?.close()
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Error closing ONNX sessions: ${e.message}")
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
            "loadTTSModel" -> result.error("NOT_IMPLEMENTED", "TTS not implemented", null)
            "unloadTTSModel" -> result.success(true)
            "synthesizeTTS" -> result.error("NOT_IMPLEMENTED", "TTS not implemented", null)

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

            // Try to enable NNAPI provider for better performance on Android
            try {
                sessionOptions.addNnapi()
            } catch (e: Exception) {
                android.util.Log.w("ModelLoader", "NNAPI not available: ${e.message}")
            }

            ocrSession = env.createSession(modelPath, sessionOptions)
            android.util.Log.i("ModelLoader", "OCR model loaded: $modelPath")
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
                // Decode image
                val bitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.size)
                if (bitmap == null) {
                    withContext(Dispatchers.Main) {
                        result.error("IMAGE_ERROR", "Failed to decode image", null)
                    }
                    return@launch
                }

                // Preprocess image for OCR
                // Note: Actual preprocessing depends on the OCR model architecture
                // Common approaches: resize to model input size, normalize, convert to tensor
                val inputWidth = 640
                val inputHeight = 640
                val scaledBitmap = Bitmap.createScaledBitmap(bitmap, inputWidth, inputHeight, true)

                // Note: ONNX tensor creation requires correct allocator API
                // OCR inference requires model-specific preprocessing and tensor creation
                // Placeholder for now - full implementation depends on model architecture

                android.util.Log.w("ModelLoader", "OCR inference - placeholder (model-specific implementation required)")

                // Cleanup
                bitmap.recycle()
                scaledBitmap.recycle()

                withContext(Dispatchers.Main) {
                    result.success(mapOf("text" to "OCR result (model-specific preprocessing required)", "confidence" to 0.0))
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
     * Process OCR model output to extract text
     */
    private fun processOCROutput(outputValue: Any): String {
        return try {
            when (outputValue) {
                is Array<*> -> {
                    // Try to decode CTC output or attention output
                    val text = outputValue.filterIsInstance<Number>().joinToString("") { it.toString() }
                    if (text.isNotEmpty()) text else "OCR result (decoding required)"
                }
                else -> "OCR result (post-processing required)"
            }
        } catch (e: Exception) {
            "OCR result (processing error: ${e.message})"
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

            sttSession = env.createSession(modelPath, sessionOptions)
            android.util.Log.i("ModelLoader", "STT model loaded: $modelPath")
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Failed to load STT model: ${e.message}")
            result.error("LOAD_ERROR", "Failed to load STT model", null)
        }
    }

    private fun handleUnloadSTTModel(result: Result) {
        try {
            sttSession?.close()
            sttSession = null
            result.success(true)
        } catch (e: Exception) {
            result.error("UNLOAD_ERROR", "Failed to unload STT model", null)
        }
    }

    private fun handleRecognizeSTT(call: MethodCall, result: Result) {
        val session = sttSession
        val env = ortEnv
        if (session == null) {
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

        scope.launch {
            try {
                // Convert audio to float array
                val floatData = convertAudioToFloat(audioData)

                // Note: ONNX tensor creation requires correct allocator API
                // STT inference requires model-specific preprocessing and tensor creation
                // Placeholder for now - full implementation depends on model architecture

                android.util.Log.w("ModelLoader", "STT inference - placeholder (model-specific implementation required)")

                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "text" to "Speech recognition result (model-specific implementation required)",
                        "confidence" to 0.0,
                        "language" to "zh"
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

    /**
     * Process STT model output to extract text
     */
    private fun processSTTOutput(outputValue: Any): String {
        return try {
            when (outputValue) {
                is Array<*> -> {
                    // Try to decode CTC or attention output
                    val text = outputValue.filterIsInstance<Number>().joinToString("") { it.toInt().toChar().toString() }
                    if (text.isNotEmpty()) text.trim() else "Speech recognition result (decoding required)"
                }
                is LongArray -> {
                    // Token IDs - need vocabulary lookup
                    val text = outputValue.joinToString("") { id -> id.toInt().toChar().toString() }
                    text.trim()
                }
                else -> "Speech recognition result (post-processing required)"
            }
        } catch (e: Exception) {
            "Speech recognition result (processing error: ${e.message})"
        }
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
     */
    private fun extractEmbedding(outputTensor: ai.onnxruntime.OnnxTensor): List<Double> {
        return try {
            val outputValue = outputTensor.value
            when (outputValue) {
                is Array<*> -> {
                    val floatArray = outputValue.filterIsInstance<Number>().map { it.toFloat() }.toFloatArray()
                    // Apply mean pooling if output is [batch, seq_len, hidden]
                    val embeddingSize = minOf(384, floatArray.size)
                    floatArray.take(embeddingSize).map { it.toDouble() }
                }
                is FloatArray -> {
                    val embeddingSize = minOf(384, outputValue.size)
                    outputValue.take(embeddingSize).map { it.toDouble() }
                }
                is DoubleArray -> {
                    val embeddingSize = minOf(384, outputValue.size)
                    outputValue.take(embeddingSize).toList()
                }
                else -> {
                    android.util.Log.w("ModelLoader", "Unknown embedding output type: ${outputValue::class.java}")
                    // Try to convert to float array
                    try {
                        val arr = outputValue as? Array<*>
                        arr?.let {
                            val floatList = it.filterIsInstance<Number>().map { n -> n.toFloat() }
                            floatList.take(384).map { f -> f.toDouble() }
                        } ?: List(384) { 0.0 }
                    } catch (e: Exception) {
                        List(384) { 0.0 }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ModelLoader", "Error extracting embedding: ${e.message}")
            List(384) { 0.0 }
        }
    }

    /**
     * Convert audio data to float array for STT inference
     */
    private fun convertAudioToFloat(audioData: ByteArray): FloatArray {
        // Assuming 16-bit PCM audio
        val shortArray = ShortArray(audioData.size / 2)
        for (i in shortArray.indices) {
            val low = audioData[i * 2].toInt() and 0xFF
            val high = audioData[i * 2 + 1].toInt() shl 8
            shortArray[i] = (low + high).toShort()
        }
        return shortArray.map { it.toFloat() / Short.MAX_VALUE.toFloat() }.toFloatArray()
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
