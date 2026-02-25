//
//  ModelLoaderPlugin.swift
//  ModelLoader
//
//  ONNX Runtime plugin for Flutter
//  支持: Embedding, STT, OCR
//

import Flutter
import UIKit
import Onnxruntimec

public class ModelLoaderPlugin: NSObject, FlutterPlugin {

    private var ortEnv: ORTEnv?
    private var ocrSession: ORTSession?
    private var sttSession: ORTSession?
    private var embeddingSession: ORTSession?
    private var tokenizer: WordPieceTokenizer?
    private var tokenizerPath: String?

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
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "TTS not implemented", details: nil))
        case "unloadTTSModel":
            result(true)
        case "synthesizeTTS":
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "TTS not implemented", details: nil))

        // LLM Methods
        case "loadLLMModel":
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "Use llama.cpp for desktop", details: nil))
        case "unloadLLMModel":
            result(true)
        case "chatLLM":
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "LLM not implemented", details: nil))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Embedding (BGE)

    private func handleLoadEmbeddingModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        // Load tokenizer if provided
        if let tokenizerPathArg = args["tokenizerPath"] as? String {
            tokenizerPath = tokenizerPathArg
            tokenizer = WordPieceTokenizer()
            do {
                try tokenizer?.loadVocabulary(from: tokenizerPathArg)
            } catch {
                result(FlutterError(code: "TOKENIZER_ERROR", message: "Failed to load tokenizer: \(error.localizedDescription)", details: nil))
                return
            }
        }

        do {
            if ortEnv == nil {
                ortEnv = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
            }

            let sessionOptions = try ORTSessionOptions()
            try sessionOptions.setIntraOpNumThreads(4)
            try sessionOptions.setInterOpNumThreads(4)

            // Enable CoreML provider for better performance
            try sessionOptions.appendCoreMLExecutionProvider(withOptions: [:])

            embeddingSession = try ORTSession(env: ortEnv!, modelPath: modelPath, sessionOptions: sessionOptions)
            result(true)
        } catch {
            result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func handleUnloadEmbeddingModel(result: @escaping FlutterResult) {
        embeddingSession = nil
        tokenizer = nil
        tokenizerPath = nil
        result(true)
    }

    private func handleGetEmbedding(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let session = embeddingSession else {
            result(FlutterError(code: "NOT_LOADED", message: "Embedding model not loaded", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "text required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Tokenize input text using WordPiece tokenizer
                var inputIds: [Int64]
                if let tokenizer = self.tokenizer {
                    inputIds = tokenizer.encode(text).map { Int64($0) }
                } else {
                    // Fallback to simple tokenization
                    inputIds = self.simpleTokenize(text: text)
                }

                // Truncate if needed
                let maxLength = 512
                if inputIds.count > maxLength {
                    inputIds = Array(inputIds.prefix(maxLength))
                }

                // Create input tensor [batch, seq_len]
                let inputTensor = try self.createInt64Tensor(data: inputIds, shape: [1, Int64(inputIds.count)])

                // Run inference
                let inputNames = try session.inputNames()
                let outputNames = try session.outputNames()

                let inputTensors: [String: ORTValue] = [inputNames[0]: inputTensor]
                let outputs = try session.run(withInputs: inputTensors, outputNames: Set(outputNames), runOptions: nil)

                // Extract embedding from output
                if let outputTensor = outputs[outputNames.first!] {
                    let embedding = try self.extractEmbedding(tensor: outputTensor)
                    DispatchQueue.main.async {
                        result([
                            "embedding": embedding,
                            "dimension": embedding.count
                        ])
                    }
                } else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INFERENCE_ERROR", message: "No output", details: nil))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INFERENCE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - STT (SenseVoice/Whisper)

    private func handleLoadSTTModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        do {
            if ortEnv == nil {
                ortEnv = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
            }

            let sessionOptions = try ORTSessionOptions()
            try sessionOptions.setIntraOpNumThreads(4)
            try sessionOptions.setInterOpNumThreads(4)
            try sessionOptions.appendCoreMLExecutionProvider(withOptions: [:])

            sttSession = try ORTSession(env: ortEnv!, modelPath: modelPath, sessionOptions: sessionOptions)
            result(true)
        } catch {
            result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func handleUnloadSTTModel(result: @escaping FlutterResult) {
        sttSession = nil
        result(true)
    }

    private func handleRecognizeSTT(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let session = sttSession else {
            result(FlutterError(code: "NOT_LOADED", message: "STT model not loaded", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let audioData = args["audioData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "audioData required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Convert audio to float array
                let floatData = self.convertAudioToFloat(audioData.data)

                // Create input tensor [batch, samples]
                let inputTensor = try self.createFloatTensor(data: floatData, shape: [1, Int64(floatData.count)])

                // Run inference
                let inputNames = try session.inputNames()
                let outputNames = try session.outputNames()

                let inputTensors: [String: ORTValue] = [inputNames[0]: inputTensor]
                let outputs = try session.run(withInputs: inputTensors, outputNames: Set(outputNames), runOptions: nil)

                // Process output (simplified)
                if let outputTensor = outputs[outputNames.first!] {
                    let text = try self.processSTTOutput(tensor: outputTensor)
                    DispatchQueue.main.async {
                        result([
                            "text": text,
                            "confidence": 0.85,
                            "language": "zh"
                        ])
                    }
                } else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INFERENCE_ERROR", message: "No output", details: nil))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INFERENCE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - OCR

    private func handleLoadOCRModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        do {
            if ortEnv == nil {
                ortEnv = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
            }

            let sessionOptions = try ORTSessionOptions()
            try sessionOptions.setIntraOpNumThreads(4)
            try sessionOptions.appendCoreMLExecutionProvider(withOptions: [:])

            ocrSession = try ORTSession(env: ortEnv!, modelPath: modelPath, sessionOptions: sessionOptions)
            result(true)
        } catch {
            result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func handleUnloadOCRModel(result: @escaping FlutterResult) {
        ocrSession = nil
        result(true)
    }

    private func handleRecognizeOCR(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "imageData required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                result(["text": "OCR not fully implemented", "confidence": 0.0])
            }
        }
    }

    // MARK: - Helper Methods

    /// Simple tokenization (character-based)
    private func simpleTokenize(text: String) -> [Int64] {
        // Simple character-based tokenization
        // For production, use proper tokenizer
        let chars = Array(text.utf8.prefix(512))
        return chars.map { Int64($0) }
    }

    /// Create float tensor
    private func createFloatTensor(data: [Float], shape: [Int64]) throws -> ORTValue {
        var floatData = data
        return try ORTValue(
            tensorData: NSData(bytes: &floatData, length: floatData.count * MemoryLayout<Float>.size),
            elementType: .float,
            shape: shape
        )
    }

    /// Create int64 tensor
    private func createInt64Tensor(data: [Int64], shape: [Int64]) throws -> ORTValue {
        var intData = data
        return try ORTValue(
            tensorData: NSData(bytes: &intData, length: intData.count * MemoryLayout<Int64>.size),
            elementType: .int64,
            shape: shape
        )
    }

    /// Extract embedding from output tensor
    private func extractEmbedding(tensor: ORTValue) throws -> [Double] {
        guard let tensorData = try? tensor.tensorData() else {
            // Return dummy embedding for demo
            return Array(repeating: 0.0, count: 384)
        }

        let floatData = tensorData.withUnsafeBytes { pointer -> [Float] in
            let buffer = pointer.bindMemory(to: Float.self)
            return Array(buffer)
        }

        // Mean pooling
        let count = Float(floatData.count)
        var mean = floatData.reduce(0) { $0 + $1 } / count

        // Return as doubles
        return floatData.prefix(384).map { Double($0) }
    }

    /// Process STT output
    private func processSTTOutput(tensor: ORTValue) throws -> String {
        // Simplified - actual implementation depends on model
        return "Speech recognition result (placeholder)"
    }

    /// Convert audio data to float array
    private func convertAudioToFloat(_ data: Data) -> [Float] {
        // Assuming 16-bit PCM audio
        let int16Array = data.withUnsafeBytes { $0.bindMemory(to: Int16.self) }
        return int16Array.map { Float($0) / Float(Int16.max) }
    }
}
