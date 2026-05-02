//
//  OnnxRuntimeManager.swift
//  ModelLoader
//
//  ONNX Runtime session management for iOS
//  Supports: Embedding, OCR, STT
//

import Foundation
import onnxruntime_objc

/// Manages ONNX Runtime environment and inference sessions
class OnnxRuntimeManager {

    static let shared = OnnxRuntimeManager()

    private var ortEnv: ORTEnv?
    private var embeddingSession: ORTSession?
    private var ocrSession: ORTSession?
    private var sttSession: ORTSession?

    /// WordPiece tokenizer for embedding models
    private var tokenizer: WordPieceTokenizer?

    /// OCR character dictionary from ppocr_keys_v1.txt
    private var ocrCharDict: [String] = []

    private init() {
        do {
            ortEnv = try ORTEnv(loggingLevel: .warning)
            print("OnnxRuntimeManager: ONNX Runtime initialized")
        } catch {
            print("OnnxRuntimeManager: Failed to initialize ONNX Runtime: \(error)")
        }
    }

    // MARK: - Session Management

    /// Create ORT session with CoreML EP fallback to CPU
    private func createSession(modelPath: String) throws -> ORTSession {
        guard let env = ortEnv else {
            throw OnnxRuntimeError.envNotInitialized
        }

        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(4)

        // Try to enable CoreML provider for better performance on iOS
        do {
            try options.appendExecutionProvider("CoreML", providerOptions: [:])
            print("OnnxRuntimeManager: CoreML provider enabled")
        } catch {
            print("OnnxRuntimeManager: CoreML not available, using CPU: \(error)")
        }

        return try ORTSession(env: env, modelPath: modelPath, sessionOptions: options)
    }

    // MARK: - Embedding

    /// Load embedding model and tokenizer
    func loadEmbeddingModel(modelPath: String, tokenizerPath: String?) throws {
        embeddingSession = try createSession(modelPath: modelPath)

        // Load tokenizer if provided
        if let tokenizerPath = tokenizerPath {
            tokenizer = WordPieceTokenizer()
            try tokenizer?.loadVocabulary(from: tokenizerPath)
            print("OnnxRuntimeManager: Tokenizer loaded from \(tokenizerPath)")
        }

        print("OnnxRuntimeManager: Embedding model loaded from \(modelPath)")
    }

    /// Unload embedding model
    func unloadEmbeddingModel() {
        embeddingSession = nil
        tokenizer = nil
    }

    /// Get embedding vector for text
    func getEmbedding(text: String) throws -> (embedding: [Double], dimension: Int) {
        guard let session = embeddingSession else {
            throw OnnxRuntimeError.modelNotLoaded("Embedding")
        }

        // Tokenize input text
        let inputIds: [Int64]
        if let tokenizer = tokenizer {
            let ids = tokenizer.encode(text)
            // Truncate to 512 tokens
            let truncated = Array(ids.prefix(512))
            inputIds = truncated.map { Int64($0) }
        } else {
            // Fallback: simple character-based tokenization
            inputIds = text.prefix(512).map { Int64($0.asciiValue ?? 0) }
        }

        let seqLen = inputIds.count
        let attentionMask = [Int64](repeating: 1, count: seqLen)
        let tokenTypeIds = [Int64](repeating: 0, count: seqLen)

        // Create input tensors
        let inputIdsTensor = try createInt64Tensor(inputIds, shape: [1, seqLen])
        let attentionMaskTensor = try createInt64Tensor(attentionMask, shape: [1, seqLen])
        let tokenTypeIdsTensor = try createInt64Tensor(tokenTypeIds, shape: [1, seqLen])

        // Build input map by matching input names
        var inputs: [String: ORTValue] = [:]
        let inputNames = try session.inputNames()
        for inputName in inputNames {
            let lower = inputName.lowercased()
            if lower.contains("attention_mask") {
                inputs[inputName] = attentionMaskTensor
            } else if lower.contains("token_type") || lower.contains("segment") {
                inputs[inputName] = tokenTypeIdsTensor
            } else {
                inputs[inputName] = inputIdsTensor
            }
        }

        // Run inference
        let outputNames = try session.outputNames()
        let outputNameSet = NSSet(array: outputNames) as! Set<String>
        let outputs = try session.run(withInputs: inputs, outputNames: outputNameSet, runOptions: nil)
        guard let firstOutputName = outputNames.first,
              let outputValue = outputs[firstOutputName] else {
            throw OnnxRuntimeError.inferenceFailed("No output from embedding model")
        }

        // Extract embedding from output tensor
        let embedding = try extractEmbedding(from: outputValue)

        print("OnnxRuntimeManager: Embedding extracted, dimension: \(embedding.count)")
        return (embedding: embedding, dimension: embedding.count)
    }

    // MARK: - OCR

    /// Load OCR model and character dictionary
    func loadOCRModel(modelPath: String, charDictPath: String?) throws {
        ocrSession = try createSession(modelPath: modelPath)

        // Load character dictionary
        if let dictPath = charDictPath {
            try loadOcrCharDict(from: dictPath)
        }

        print("OnnxRuntimeManager: OCR model loaded from \(modelPath)")
    }

    /// Unload OCR model
    func unloadOCRModel() {
        ocrSession = nil
        ocrCharDict = []
    }

    /// Recognize text from image data
    func recognizeOCR(imageData: Data) throws -> (text: String, confidence: Double) {
        guard let session = ocrSession else {
            throw OnnxRuntimeError.modelNotLoaded("OCR")
        }

        // Decode image
        guard let image = UIImage(data: imageData) else {
            throw OnnxRuntimeError.imageDecodeFailed
        }

        // Resize to 48x320 (PaddleOCR PP-OCRv4 input size)
        let inputHeight = 48
        let inputWidth = 320
        guard let resizedImage = resizeImage(image, to: CGSize(width: inputWidth, height: inputHeight)) else {
            throw OnnxRuntimeError.imageResizeFailed
        }

        // Convert to NCHW RGB float buffer normalized to [-1, 1]
        let floatBuffer = imageToRgbFloatBuffer(resizedImage)

        // Create input tensor [1, 3, 48, 320]
        let inputData = NSMutableData(bytes: floatBuffer, length: floatBuffer.count * MemoryLayout<Float>.size)
        let inputTensor = try ORTValue(
            tensorData: inputData,
            elementType: .float,
            shape: [1, 3, NSNumber(value: inputHeight), NSNumber(value: inputWidth)]
        )

        // Run inference
        let inputNames = try session.inputNames()
        let inputName = inputNames.first ?? "x"
        let outputNames = try session.outputNames()
        let outputNameSet = NSSet(array: outputNames) as! Set<String>
        let outputs = try session.run(withInputs: [inputName: inputTensor], outputNames: outputNameSet, runOptions: nil)

        guard let firstOutputName = outputNames.first,
              let outputValue = outputs[firstOutputName] else {
            throw OnnxRuntimeError.inferenceFailed("No output from OCR model")
        }

        // Extract logits and decode
        let (text, confidence) = try ctcGreedyDecode(from: outputValue)

        print("OnnxRuntimeManager: OCR result: '\(text)' (conf=\(String(format: "%.2f", confidence)))")
        return (text: text, confidence: confidence)
    }

    // MARK: - STT

    /// Load STT model
    func loadSTTModel(modelPath: String) throws {
        sttSession = try createSession(modelPath: modelPath)
        print("OnnxRuntimeManager: STT model loaded from \(modelPath)")
    }

    /// Unload STT model
    func unloadSTTModel() {
        sttSession = nil
    }

    /// Recognize speech from audio data (placeholder - model-specific implementation required)
    func recognizeSTT(audioData: Data) throws -> (text: String, confidence: Double, language: String) {
        guard sttSession != nil else {
            throw OnnxRuntimeError.modelNotLoaded("STT")
        }

        // STT inference requires model-specific preprocessing
        // Return clear error instead of placeholder data
        throw OnnxRuntimeError.inferenceFailed("STT inference not yet fully implemented on iOS")
    }

    // MARK: - Tensor Helpers

    /// Create Int64 tensor from array
    private func createInt64Tensor(_ values: [Int64], shape: [Int]) throws -> ORTValue {
        var mutableValues = values
        let data = NSMutableData(bytes: &mutableValues, length: values.count * MemoryLayout<Int64>.size)
        let nsShape = shape.map { NSNumber(value: $0) }
        return try ORTValue(tensorData: data, elementType: .int64, shape: nsShape)
    }

    /// Extract embedding from output ORTValue
    private func extractEmbedding(from outputValue: ORTValue) throws -> [Double] {
        let outputData = try outputValue.tensorData()
        let floatCount = outputData.count / MemoryLayout<Float>.size

        // Try to interpret as [batch, seq_len, hidden] and take first 384 dims
        var embedding = [Double]()
        embedding.reserveCapacity(min(384, floatCount))

        let bytes = outputData.bytes.bindMemory(to: Float.self, capacity: floatCount)
        let count = min(384, floatCount)
        for i in 0..<count {
            embedding.append(Double(bytes[i]))
        }

        return embedding
    }

    /// Load OCR character dictionary from ppocr_keys_v1.txt
    private func loadOcrCharDict(from path: String) throws {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        ocrCharDict = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        print("OnnxRuntimeManager: OCR char dict loaded: \(ocrCharDict.count) chars")
    }

    /// CTC greedy decode: argmax per timestep, collapse repeats, remove blank (index 0)
    private func ctcGreedyDecode(from outputValue: ORTValue) throws -> (text: String, confidence: Double) {
        let outputData = try outputValue.tensorData()

        // Output shape is typically [1, seq_len, num_classes]
        // We need to determine the dimensions from the tensor
        let typeAndShapeInfo = try outputValue.tensorTypeAndShapeInfo()
        let shape = typeAndShapeInfo.shape
        guard shape.count >= 2 else {
            throw OnnxRuntimeError.inferenceFailed("OCR output shape invalid")
        }

        let seqLen = shape[shape.count - 2].intValue
        let numClasses = shape[shape.count - 1].intValue

        var text = ""
        var totalConf: Float = 0.0
        var charCount = 0
        var lastIdx = -1

        let floatBuffer = outputData.bytes.bindMemory(to: Float.self, capacity: seqLen * numClasses)

        for t in 0..<seqLen {
            let offset = t * numClasses
            var maxIdx = 0
            var maxVal = floatBuffer[offset]

            for c in 1..<numClasses {
                let val = floatBuffer[offset + c]
                if val > maxVal {
                    maxVal = val
                    maxIdx = c
                }
            }

            // CTC decode: skip blank (0), collapse repeats
            if maxIdx != 0 && maxIdx != lastIdx {
                let charIdx = maxIdx - 1
                if charIdx < ocrCharDict.count {
                    text += ocrCharDict[charIdx]
                } else {
                    text += "?"
                }
            }

            totalConf += maxVal
            charCount += 1
            lastIdx = maxIdx
        }

        let confidence = charCount > 0 ? Double(totalConf / Float(charCount)) : 0.0
        return (text: text, confidence: confidence)
    }

    // MARK: - Image Helpers

    /// Resize UIImage to target size
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }

    /// Convert UIImage to NCHW RGB float buffer normalized to [-1, 1]
    private func imageToRgbFloatBuffer(_ image: UIImage) -> [Float] {
        guard let cgImage = image.cgImage else {
            return [Float](repeating: 0, count: 3 * 48 * 320)
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height

        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        pixelData.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        // Convert to NCHW RGB normalized to [-1, 1]
        var rPlane = [Float](repeating: 0, count: height * width)
        var gPlane = [Float](repeating: 0, count: height * width)
        var bPlane = [Float](repeating: 0, count: height * width)

        for i in 0..<(height * width) {
            let offset = i * bytesPerPixel
            rPlane[i] = (Float(pixelData[offset]) / 255.0 - 0.5) / 0.5
            gPlane[i] = (Float(pixelData[offset + 1]) / 255.0 - 0.5) / 0.5
            bPlane[i] = (Float(pixelData[offset + 2]) / 255.0 - 0.5) / 0.5
        }

        return rPlane + gPlane + bPlane
    }
}

// MARK: - Error Types

enum OnnxRuntimeError: Error, LocalizedError {
    case envNotInitialized
    case modelNotLoaded(String)
    case inferenceFailed(String)
    case imageDecodeFailed
    case imageResizeFailed

    var errorDescription: String? {
        switch self {
        case .envNotInitialized:
            return "ONNX Runtime environment not initialized"
        case .modelNotLoaded(let name):
            return "\(name) model not loaded"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        case .imageDecodeFailed:
            return "Failed to decode image data"
        case .imageResizeFailed:
            return "Failed to resize image"
        }
    }
}
