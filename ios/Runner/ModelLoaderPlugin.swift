//
//  ModelLoaderPlugin.swift
//  ModelLoader
//
//  ONNX Runtime plugin for Flutter
//  支持: Embedding, STT, OCR
//

import Flutter
import UIKit
import AVFoundation

@_silgen_name("LlamaBridgeLoadModel")
private func LlamaBridgeLoadModel(
    _ modelPath: UnsafePointer<CChar>,
    _ contextLength: Int32,
    _ threads: Int32,
    _ gpuLayers: Int32,
    _ useGpu: Bool
) -> Bool

@_silgen_name("LlamaBridgeUnloadModel")
private func LlamaBridgeUnloadModel()

@_silgen_name("LlamaBridgeIsLoaded")
private func LlamaBridgeIsLoaded() -> Bool

@_silgen_name("LlamaBridgeFileExists")
private func LlamaBridgeFileExists(_ modelPath: UnsafePointer<CChar>) -> Bool

@_silgen_name("LlamaBridgeChat")
private func LlamaBridgeChat(
    _ prompt: UnsafePointer<CChar>,
    _ maxTokens: Int32,
    _ temperature: Double,
    _ topP: Double,
    _ topK: Int32,
    _ repeatPenalty: Double,
    _ seed: Int32
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("LlamaBridgeChatMessages")
private func LlamaBridgeChatMessages(
    _ roles: UnsafePointer<UnsafePointer<CChar>?>,
    _ contents: UnsafePointer<UnsafePointer<CChar>?>,
    _ count: Int32,
    _ maxTokens: Int32,
    _ temperature: Double,
    _ topP: Double,
    _ topK: Int32,
    _ repeatPenalty: Double,
    _ seed: Int32
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("LlamaBridgeFreeString")
private func LlamaBridgeFreeString(_ ptr: UnsafeMutablePointer<CChar>)

public class ModelLoaderPlugin: NSObject, FlutterPlugin {

    private let maxTokensUpperBound = 2048

    // TTS engine
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var ttsInitialized = false

    private struct NativeChatMessages {
        let roles: [String]
        let contents: [String]
    }

    private func normalizedBundledAssetPath(_ rawPath: String) -> String? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.contains("..") else {
            return nil
        }
        return trimmed
    }

    private func bundledFlutterAssetsRoot() -> String? {
        if let frameworksPath = Bundle.main.privateFrameworksPath {
            let root = (frameworksPath as NSString)
                .appendingPathComponent("App.framework/flutter_assets")
            let resolved = (root as NSString).resolvingSymlinksInPath
            if FileManager.default.fileExists(atPath: resolved) {
                return resolved
            }
        }

        if let resourcePath = Bundle.main.resourcePath {
            let root = (resourcePath as NSString)
                .appendingPathComponent("Frameworks/App.framework/flutter_assets")
            let resolved = (root as NSString).resolvingSymlinksInPath
            if FileManager.default.fileExists(atPath: resolved) {
                return resolved
            }
        }

        return nil
    }

    private func isPath(_ resolvedPath: String, within allowedRoot: String) -> Bool {
        if resolvedPath == allowedRoot {
            return true
        }

        let normalizedRoot = allowedRoot.hasSuffix("/") ? allowedRoot : allowedRoot + "/"
        return resolvedPath.hasPrefix(normalizedRoot)
    }

    private func resolveBundledAssetPath(_ assetPath: String) -> String? {
        guard let assetsRoot = bundledFlutterAssetsRoot() else { return nil }

        let candidate = (assetsRoot as NSString).appendingPathComponent(assetPath)
        let standardized = (candidate as NSString).standardizingPath
        let resolved = (standardized as NSString).resolvingSymlinksInPath

        guard isPath(resolved, within: assetsRoot) else { return nil }
        guard FileManager.default.fileExists(atPath: resolved) else { return nil }

        return resolved
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.modelloader/model_runtime",
            binaryMessenger: registrar.messenger()
        )

        let instance = ModelLoaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // OCR Methods
        case "loadOCRModel":
            handleLoadOCRModel(call: call, result: result)
        case "unloadOCRModel":
            handleUnloadOCRModel(result: result)
        case "recognizeOCR":
            handleRecognizeOCR(call: call, result: result)

        // STT Methods (SenseVoice/Whisper)
        case "loadSTTModel":
            handleLoadSTTModel(call: call, result: result)
        case "unloadSTTModel":
            handleUnloadSTTModel(result: result)
        case "recognizeSTT":
            handleRecognizeSTT(call: call, result: result)

        // Embedding Methods (BGE)
        case "loadEmbeddingModel":
            handleLoadEmbeddingModel(call: call, result: result)
        case "unloadEmbeddingModel":
            handleUnloadEmbeddingModel(result: result)
        case "getEmbedding":
            handleGetEmbedding(call: call, result: result)

        // TTS Methods
        case "loadTTSModel":
            handleLoadTTSModel(call: call, result: result)
        case "unloadTTSModel":
            handleUnloadTTSModel(result: result)
        case "synthesizeTTS":
            handleSynthesizeTTS(call: call, result: result)

        // Image Captioning Methods
        case "loadImageCaptionModel":
            handleLoadImageCaptionModel(call: call, result: result)
        case "unloadImageCaptionModel":
            handleUnloadImageCaptionModel(result: result)
        case "captionImage":
            handleCaptionImage(call: call, result: result)

        // LLM Methods
        case "loadLLMModel":
            handleLoadLLMModel(call: call, result: result)
        case "unloadLLMModel":
            handleUnloadLLMModel(result: result)
        case "chatLLM":
            handleChatLLM(call: call, result: result)
        case "chatLLMStream":
            handleChatLLMStream(call: call, result: result)
        case "prepareBundledAsset":
            handlePrepareBundledAsset(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func runtimeUnavailableError(_ capability: String) -> FlutterError {
        FlutterError(
            code: "RUNTIME_NOT_AVAILABLE",
            message: "\(capability) runtime is not available on iOS in this build",
            details: "The iOS ONNX integration is not production-ready yet."
        )
    }

    // MARK: - Embedding

    private func handleLoadEmbeddingModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPathArg = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        // Resolve model path
        let modelPath: String
        if let resolved = resolveBundledAssetPath(modelPathArg) {
            modelPath = resolved
        } else {
            modelPath = modelPathArg
        }

        // Resolve tokenizer path
        let tokenizerPath: String?
        if let tokenizerPathArg = args["tokenizerPath"] as? String {
            if let resolved = resolveBundledAssetPath(tokenizerPathArg) {
                tokenizerPath = resolved
            } else {
                tokenizerPath = tokenizerPathArg
            }
        } else {
            // Try to find tokenizer.json or vocab.txt near model
            let modelDir = (modelPath as NSString).deletingLastPathComponent
            let tokenizerJson = (modelDir as NSString).appendingPathComponent("tokenizer.json")
            let vocabTxt = (modelDir as NSString).appendingPathComponent("vocab.txt")
            if FileManager.default.fileExists(atPath: tokenizerJson) {
                tokenizerPath = tokenizerJson
            } else if FileManager.default.fileExists(atPath: vocabTxt) {
                tokenizerPath = vocabTxt
            } else {
                tokenizerPath = nil
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try OnnxRuntimeManager.shared.loadEmbeddingModel(
                    modelPath: modelPath,
                    tokenizerPath: tokenizerPath
                )
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOAD_ERROR", message: "Failed to load embedding model: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }

    private func handleUnloadEmbeddingModel(result: @escaping FlutterResult) {
        OnnxRuntimeManager.shared.unloadEmbeddingModel()
        result(true)
    }

    private func handleGetEmbedding(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "text required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (embedding, dimension) = try OnnxRuntimeManager.shared.getEmbedding(text: text)
                DispatchQueue.main.async {
                    result([
                        "embedding": embedding,
                        "dimension": dimension
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INFERENCE_ERROR", message: "Embedding inference failed: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }

    // MARK: - STT

    private func handleLoadSTTModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPathArg = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        let modelPath: String
        if let resolved = resolveBundledAssetPath(modelPathArg) {
            modelPath = resolved
        } else {
            modelPath = modelPathArg
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try OnnxRuntimeManager.shared.loadSTTModel(modelPath: modelPath)
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOAD_ERROR", message: "Failed to load STT model: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }

    private func handleUnloadSTTModel(result: @escaping FlutterResult) {
        OnnxRuntimeManager.shared.unloadSTTModel()
        result(true)
    }

    private func handleRecognizeSTT(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let audioData = args["audioData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "audioData required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (text, confidence, language) = try OnnxRuntimeManager.shared.recognizeSTT(audioData: audioData.data)
                DispatchQueue.main.async {
                    result([
                        "text": text,
                        "confidence": confidence,
                        "language": language
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INFERENCE_ERROR", message: "STT inference failed: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }

    // MARK: - OCR

    private func handleLoadOCRModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPathArg = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        let modelPath: String
        if let resolved = resolveBundledAssetPath(modelPathArg) {
            modelPath = resolved
        } else {
            modelPath = modelPathArg
        }

        // Resolve character dictionary path
        let charDictPath: String?
        let modelDir = (modelPath as NSString).deletingLastPathComponent
        let dictPath = (modelDir as NSString).appendingPathComponent("ppocr_keys_v1.txt")
        if FileManager.default.fileExists(atPath: dictPath) {
            charDictPath = dictPath
        } else if let resolved = resolveBundledAssetPath("assets/models/ocr/ppocr_keys_v1.txt") {
            charDictPath = resolved
        } else {
            charDictPath = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try OnnxRuntimeManager.shared.loadOCRModel(
                    modelPath: modelPath,
                    charDictPath: charDictPath
                )
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOAD_ERROR", message: "Failed to load OCR model: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }

    private func handleUnloadOCRModel(result: @escaping FlutterResult) {
        OnnxRuntimeManager.shared.unloadOCRModel()
        result(true)
    }

    private func handleRecognizeOCR(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "imageData required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (text, confidence) = try OnnxRuntimeManager.shared.recognizeOCR(imageData: imageData.data)
                DispatchQueue.main.async {
                    result([
                        "text": text,
                        "confidence": confidence
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INFERENCE_ERROR", message: "OCR inference failed: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }

    // MARK: - TTS (AVSpeechSynthesizer)

    private func handleLoadTTSModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let language: String
        if let args = call.arguments as? [String: Any],
           let lang = args["language"] as? String {
            language = lang
        } else {
            language = "en-US"
        }

        // AVSpeechSynthesizer doesn't require model loading, just mark as initialized
        ttsInitialized = true
        NSLog("ModelLoader: TTS loaded for language: \(language)")
        result(true)
    }

    private func handleUnloadTTSModel(result: @escaping FlutterResult) {
        ttsInitialized = false
        NSLog("ModelLoader: TTS unloaded")
        result(true)
    }

    private func handleSynthesizeTTS(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String,
              let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "text and outputPath are required", details: nil))
            return
        }

        let utterance = AVSpeechUtterance(string: text)

        // Set language
        let language = args["language"] as? String ?? "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode(for: language))

        // Set rate if provided
        if let rate = args["rate"] as? Double {
            utterance.rate = Float(rate)
        }

        // Set pitch if provided
        if let pitch = args["pitch"] as? Double {
            utterance.pitchMultiplier = Float(pitch)
        }

        // Set volume if provided
        if let volume = args["volume"] as? Double {
            utterance.volume = Float(volume)
        }

        // iOS AVSpeechSynthesizer does not support direct file output.
        // It can only play audio through speakers. The file path is returned
        // as a acknowledgment but actual audio is played, not saved.
        // For proper file output on iOS, AVAudioEngine would be required.
        speechSynthesizer.speak(utterance)
        NSLog("ModelLoader: TTS speaking (file output not supported on iOS): \(outputPath)")
        result(outputPath)
    }

    // MARK: - Image Captioning

    private func handleLoadImageCaptionModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath is required", details: nil))
            return
        }

        do {
            try OnnxRuntimeManager.shared.loadImageCaptionModel(modelPath: modelPath)
            NSLog("ModelLoader: Image Captioning model loaded")
            result(true)
        } catch {
            NSLog("ModelLoader: Failed to load Image Captioning model: \(error)")
            result(FlutterError(code: "LOAD_ERROR", message: "Failed to load Image Captioning model: \(error.localizedDescription)", details: nil))
        }
    }

    private func handleUnloadImageCaptionModel(result: @escaping FlutterResult) {
        OnnxRuntimeManager.shared.unloadImageCaptionModel()
        NSLog("ModelLoader: Image Captioning model unloaded")
        result(true)
    }

    private func handleCaptionImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "imageData is required", details: nil))
            return
        }

        do {
            let data = imageData.data
            let captionResult = try OnnxRuntimeManager.shared.captionImage(imageData: data)
            result([
                "caption": captionResult.caption,
                "confidence": captionResult.confidence,
                "candidates": captionResult.candidates.map { ["text": $0.text, "confidence": $0.confidence] }
            ])
        } catch {
            NSLog("ModelLoader: Image caption failed: \(error)")
            result(FlutterError(code: "CAPTION_ERROR", message: "Image caption failed: \(error.localizedDescription)", details: nil))
        }
    }

    private func languageCode(for language: String) -> String {
        switch language {
        case let l where l.hasPrefix("zh"):
            return "zh-CN"
        case let l where l.hasPrefix("ja"):
            return "ja-JP"
        case let l where l.hasPrefix("ko"):
            return "ko-KR"
        case let l where l.hasPrefix("es"):
            return "es-ES"
        case let l where l.hasPrefix("fr"):
            return "fr-FR"
        case let l where l.hasPrefix("de"):
            return "de-DE"
        default:
            return "en-US"
        }
    }

    // MARK: - LLM (native llama bridge)

    private var llmLoaded: Bool = false

    private func validateLlmModelPath(_ rawPath: String) -> String? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let fileUrl = URL(fileURLWithPath: trimmed).standardizedFileURL
        guard fileUrl.pathExtension.lowercased() == "gguf" else { return nil }

        let resolvedFilePath = (fileUrl.path as NSString).resolvingSymlinksInPath
        guard FileManager.default.fileExists(atPath: resolvedFilePath) else { return nil }

        let cachesUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let modelsUrl = cachesUrl?.appendingPathComponent("models", isDirectory: true).standardizedFileURL
        guard let allowedRootRaw = modelsUrl?.path else { return nil }
        let allowedRoot = (allowedRootRaw as NSString).resolvingSymlinksInPath
        let bundledRoot = bundledFlutterAssetsRoot()

        let isInCache = isPath(resolvedFilePath, within: allowedRoot)
        let isInBundle = bundledRoot.map { isPath(resolvedFilePath, within: $0) } ?? false
        guard isInCache || isInBundle else { return nil }

        return resolvedFilePath
    }

    private func clampTemperature(_ value: Double) -> Double {
        min(max(value, 0.0), 2.0)
    }

    private func clampTopP(_ value: Double) -> Double {
        min(max(value, 0.05), 1.0)
    }

    private func clampTopK(_ value: Int) -> Int {
        max(value, 1)
    }

    private func clampRepeatPenalty(_ value: Double) -> Double {
        min(max(value, 0.0), 2.0)
    }

    private func clampMaxTokens(_ value: Int) -> Int {
        min(max(value, 1), maxTokensUpperBound)
    }

    private func clampContextLength(_ value: Int) -> Int {
        min(max(value, 512), 8192)
    }

    private func normalizeChatRole(_ rawRole: Any?) -> String {
        let rawValue = rawRole.map { String(describing: $0) } ?? ""
        let role = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch role {
        case "system":
            return "system"
        case "assistant":
            return "assistant"
        default:
            return "user"
        }
    }

    private func normalizeChatMessages(_ rawMessages: [[String: Any]]) -> NativeChatMessages? {
        var roles: [String] = []
        var contents: [String] = []
        roles.reserveCapacity(rawMessages.count)
        contents.reserveCapacity(rawMessages.count)

        for message in rawMessages {
            let content = message["content"].map { String(describing: $0) } ?? ""
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            roles.append(normalizeChatRole(message["role"]))
            contents.append(content)
        }

        guard !roles.isEmpty else { return nil }
        return NativeChatMessages(roles: roles, contents: contents)
    }

    private func withDuplicatedCStrings<T>(_ strings: [String], body: ([UnsafePointer<CChar>?]) -> T) -> T {
        let duplicated = strings.map { strdup($0) }
        defer {
            for pointer in duplicated {
                free(pointer)
            }
        }

        return body(duplicated.map { pointer in
            pointer.map { UnsafePointer<CChar>($0) }
        })
    }

    private func normalizeThreads(_ value: Int?) -> Int {
        min(max(value ?? 0, 0), 32)
    }

    private func normalizeGpuLayers(_ value: Int?, useGpu: Bool) -> Int {
        guard useGpu else { return 0 }
        return max(value ?? 0, 0)
    }

    private func handleLoadLLMModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPathArg = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        guard let modelPath = validateLlmModelPath(modelPathArg) else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "modelPath must be a .gguf file under app cache/models or bundled flutter_assets",
                details: nil
            ))
            return
        }

        let contextLength = clampContextLength(args["contextLength"] as? Int ?? 2048)
        let threads = normalizeThreads(args["threads"] as? Int)
        let useGpu = args["useGpu"] as? Bool ?? true
        let gpuLayers = normalizeGpuLayers(args["gpuLayers"] as? Int, useGpu: useGpu)

        let exists = modelPath.withCString { cModelPath in
            LlamaBridgeFileExists(cModelPath)
        }

        guard exists else {
            result(FlutterError(code: "LOAD_ERROR", message: "Model file not found", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = modelPath.withCString { cModelPath in
                LlamaBridgeLoadModel(
                    cModelPath,
                    Int32(contextLength),
                    Int32(threads),
                    Int32(gpuLayers),
                    useGpu
                )
            }

            self.llmLoaded = loaded
            DispatchQueue.main.async {
                if loaded {
                    result(true)
                } else {
                    result(FlutterError(code: "LOAD_ERROR", message: "Failed to load LLM model via native bridge", details: nil))
                }
            }
        }
    }

    private func handleUnloadLLMModel(result: @escaping FlutterResult) {
        LlamaBridgeUnloadModel()
        llmLoaded = false
        result(true)
    }

    private func handleChatLLM(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard llmLoaded, LlamaBridgeIsLoaded() else {
            result(FlutterError(code: "NOT_LOADED", message: "LLM model not loaded", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let messages = args["messages"] as? [[String: Any]] else {
            result(FlutterError(code: "INVALID_ARGS", message: "messages required", details: nil))
            return
        }

        guard let normalizedMessages = normalizeChatMessages(messages) else {
            result(FlutterError(code: "INVALID_ARGS", message: "messages must include at least one non-empty entry", details: nil))
            return
        }

        let temperature = clampTemperature(args["temperature"] as? Double ?? 0.7)
        let maxTokens = clampMaxTokens(args["maxTokens"] as? Int ?? 2048)
        let topP = clampTopP(args["topP"] as? Double ?? 0.9)
        let topK = clampTopK(args["topK"] as? Int ?? 40)
        let repeatPenalty = clampRepeatPenalty(args["repeatPenalty"] as? Double ?? 1.0)
        let seed = args["seed"] as? Int ?? -1

        DispatchQueue.global(qos: .userInitiated).async {
            let response: String = self.withDuplicatedCStrings(normalizedMessages.roles) { cRoles in
                self.withDuplicatedCStrings(normalizedMessages.contents) { cContents in
                    cRoles.withUnsafeBufferPointer { roleBuffer in
                        cContents.withUnsafeBufferPointer { contentBuffer in
                            guard let roleBase = roleBuffer.baseAddress,
                                  let contentBase = contentBuffer.baseAddress,
                                  let cResult = LlamaBridgeChatMessages(
                                      roleBase,
                                      contentBase,
                                      Int32(normalizedMessages.roles.count),
                                      Int32(maxTokens),
                                      temperature,
                                      topP,
                                      Int32(topK),
                                      repeatPenalty,
                                      Int32(seed)
                                  ) else {
                                return ""
                            }
                            defer { LlamaBridgeFreeString(cResult) }
                            return String(cString: cResult)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                if response.isEmpty {
                    result(FlutterError(code: "INFERENCE_FAILED", message: "LLM native inference returned empty output", details: nil))
                } else {
                    result(response)
                }
            }
        }
    }

    private func handleChatLLMStream(call: FlutterMethodCall, result: @escaping FlutterResult) {
        handleChatLLM(call: call, result: result)
    }

    private func handlePrepareBundledAsset(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let assetPathArg = args["assetPath"] as? String,
              let assetPath = normalizedBundledAssetPath(assetPathArg) else {
            result(FlutterError(code: "INVALID_ARGS", message: "assetPath required", details: nil))
            return
        }

        guard let resolvedPath = resolveBundledAssetPath(assetPath) else {
            result(FlutterError(code: "ASSET_NOT_FOUND", message: "Bundled asset not found", details: nil))
            return
        }

        result(resolvedPath)
    }
}
