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
    private var sttEncoderSession: ORTSession?
    private var sttDecoderSession: ORTSession?
    private var sttVocab: [Int: String] = [:]

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

        // Validate image data
        guard !imageData.isEmpty else {
            throw OnnxRuntimeError.imageDecodeFailed
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
        let floatBuffer = try imageToRgbFloatBuffer(resizedImage)

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

    // MARK: - STT (Whisper)

    // Whisper audio parameters
    private let sttSampleRate: Int = 16000
    private let sttHopLength: Int = 160
    private let sttWinLength: Int = 400
    private let sttNFFT: Int = 512
    private let sttNMels: Int = 80
    private let sttFMin: Double = 0.0
    private let sttFMax: Double = 8000.0
    private let sttMaxAudioLength: Int = 480000

    // Whisper special token IDs
    private let tokenNoTimestamps = 50363
    private let tokenTranscribe = 50359
    private let tokenTranslate = 50358
    private let tokenStartOfTranscript = 50258
    private let tokenEndOfTranscript = 50257
    private let tokenTimestampBegin = 50364

    /// Load STT encoder and decoder models separately
    func loadSTTModel(modelPath: String) throws {
        let modelDir = (modelPath as NSString).deletingLastPathComponent
        let encoderPath = (modelDir as NSString).appendingPathComponent("onnx/encoder_model.onnx")
        let decoderPath = (modelDir as NSString).appendingPathComponent("onnx/decoder_model_merged.onnx")

        guard FileManager.default.fileExists(atPath: encoderPath) else {
            throw OnnxRuntimeError.inferenceFailed("STT encoder not found at \(encoderPath)")
        }
        guard FileManager.default.fileExists(atPath: decoderPath) else {
            throw OnnxRuntimeError.inferenceFailed("STT decoder not found at \(decoderPath)")
        }

        sttEncoderSession = try createSession(modelPath: encoderPath)
        print("OnnxRuntimeManager: STT encoder loaded from \(encoderPath)")

        sttDecoderSession = try createSession(modelPath: decoderPath)
        print("OnnxRuntimeManager: STT decoder loaded from \(decoderPath)")

        // Load vocabulary
        loadSTTVocabulary(modelDir: modelDir)
    }

    /// Unload STT model
    func unloadSTTModel() {
        sttEncoderSession = nil
        sttDecoderSession = nil
        sttVocab = [:]
    }

    /// Load vocab.json for token-to-text decoding
    private func loadSTTVocabulary(modelDir: String) {
        let vocabPath = (modelDir as NSString).appendingPathComponent("vocab.json")
        guard FileManager.default.fileExists(atPath: vocabPath) else {
            print("OnnxRuntimeManager: STT vocab.json not found at \(vocabPath)")
            return
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: vocabPath))
            if let map = try JSONSerialization.jsonObject(with: data) as? [String: Int] {
                sttVocab = Dictionary(uniqueKeysWithValues: map.map { ($0.value, $0.key) })
                print("OnnxRuntimeManager: STT vocab loaded: \(sttVocab.count) tokens")
            }
        } catch {
            print("OnnxRuntimeManager: Failed to load STT vocab: \(error)")
        }
    }

    /// Recognize speech from audio data (16-bit PCM, 16kHz, mono)
    func recognizeSTT(audioData: Data) throws -> (text: String, confidence: Double, language: String) {
        guard let encoderSession = sttEncoderSession, let decoderSession = sttDecoderSession else {
            throw OnnxRuntimeError.modelNotLoaded("STT")
        }
        guard audioData.count >= 100 else {
            throw OnnxRuntimeError.inferenceFailed("Audio data too short (min 100 bytes)")
        }

        // Convert 16-bit PCM to float
        let floatData = convertAudioToFloat(data: audioData)
        print("OnnxRuntimeManager: STT audio samples: \(floatData.count)")

        // Compute log-mel spectrogram
        let melSpectrogram = computeLogMelSpectrogram(audioFloat: floatData)
        print("OnnxRuntimeManager: STT mel shape: [\(melSpectrogram.count), \(melSpectrogram[0].count)]")

        // Run encoder
        let encoderOutput = try runEncoderInference(session: encoderSession, melSpectrogram: melSpectrogram)
        print("OnnxRuntimeManager: STT encoder output: [\(encoderOutput.count), \(encoderOutput[0].count)]")

        // Run decoder (autoregressive)
        let (tokens, confidence) = try runDecoderInference(session: decoderSession, encoderOutput: encoderOutput)
        print("OnnxRuntimeManager: STT generated \(tokens.count) tokens, conf=\(String(format: "%.2f", confidence))")

        // Decode tokens to text
        let text = decodeTokens(tokens: tokens)
        print("OnnxRuntimeManager: STT result: '\(text)'")
        return (text: text, confidence: confidence, language: "auto")
    }

    // MARK: - STT Audio Processing

    /// Convert 16-bit PCM byte data to float array
    private func convertAudioToFloat(data: Data) -> [Float] {
        let sampleCount = data.count / 2
        var samples = [Float](repeating: 0, count: sampleCount)
        data.withUnsafeBytes { rawBuffer in
            let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                samples[i] = Float(int16Buffer[i]) / 32768.0
            }
        }
        return samples
    }

    /// Compute log-mel spectrogram [80, 3000]
    private func computeLogMelSpectrogram(audioFloat: [Float]) -> [[Float]] {
        // Pad or trim to MAX_AUDIO_LENGTH
        var audio = audioFloat
        if audio.count < sttMaxAudioLength {
            audio.append(contentsOf: [Float](repeating: 0, count: sttMaxAudioLength - audio.count))
        } else if audio.count > sttMaxAudioLength {
            audio = Array(audio.prefix(sttMaxAudioLength))
        }

        // Hann window
        let window = (0..<sttWinLength).map { i -> Float in
            Float(0.5 * (1.0 - cos(2.0 * Double.pi * Double(i) / Double(sttWinLength - 1))))
        }

        let nFrames = (audio.count - sttWinLength) / sttHopLength + 1
        let melFilterbank = computeMelFilterbank()

        var spectrogram = [[Float]](repeating: [Float](repeating: 0, count: nFrames), count: sttNMels)

        // FFT buffers
        var fftReal = [Float](repeating: 0, count: sttNFFT)
        var fftImag = [Float](repeating: 0, count: sttNFFT)
        let outSize = sttNFFT / 2 + 1

        for frameIdx in 0..<nFrames {
            let start = frameIdx * sttHopLength

            // Apply window, zero-pad to N_FFT
            for i in 0..<sttWinLength {
                fftReal[i] = audio[start + i] * window[i]
            }
            for i in sttWinLength..<sttNFFT {
                fftReal[i] = 0
            }
            for i in 0..<sttNFFT {
                fftImag[i] = 0
            }

            // Radix-2 FFT (in-place)
            fftInPlace(real: &fftReal, imag: &fftImag)

            // Power spectrum
            var power = [Float](repeating: 0, count: outSize)
            for i in 0..<outSize {
                power[i] = fftReal[i] * fftReal[i] + fftImag[i] * fftImag[i]
            }

            // Apply mel filterbank
            for m in 0..<sttNMels {
                var sum: Float = 0
                for k in 0..<outSize {
                    sum += power[k] * melFilterbank[m][k]
                }
                spectrogram[m][frameIdx] = sum > 1e-10 ? log10(max(sum, 1e-10)) : -10
            }
        }

        return spectrogram
    }

    /// In-place radix-2 Cooley-Tukey FFT
    private func fftInPlace(real: inout [Float], imag: inout [Float]) {
        let n = real.count
        let bits = Int(log2(Double(n)))

        // Bit-reversal permutation
        for i in 0..<n {
            var j = 0
            for b in 0..<bits {
                if (i >> b) & 1 == 1 {
                    j |= 1 << (bits - 1 - b)
                }
            }
            if i < j {
                real.swapAt(i, j)
                imag.swapAt(i, j)
            }
        }

        // Cooley-Tukey butterfly
        var size = 2
        while size <= n {
            let halfSize = size / 2
            let angleStep = -2.0 * Double.pi / Double(size)

            for i in stride(from: 0, to: n, by: size) {
                for j in 0..<halfSize {
                    let angle = angleStep * Double(j)
                    let wReal = Float(cos(angle))
                    let wImag = Float(sin(angle))

                    let idx1 = i + j
                    let idx2 = idx1 + halfSize

                    let vWReal = real[idx2] * wReal - imag[idx2] * wImag
                    let vWImag = real[idx2] * wImag + imag[idx2] * wReal

                    real[idx2] = real[idx1] - vWReal
                    imag[idx2] = imag[idx1] - vWImag
                    real[idx1] = real[idx1] + vWReal
                    imag[idx1] = imag[idx1] + vWImag
                }
            }
            size *= 2
        }
    }

    /// Compute mel filterbank [NMels, NFFT/2+1]
    private func computeMelFilterbank() -> [[Float]] {
        func hzToMel(_ hz: Double) -> Double { 2595.0 * log10(1.0 + hz / 700.0) }
        func melToHz(_ mel: Double) -> Double { 700.0 * (pow(10.0, mel / 2595.0) - 1.0) }

        let lowMel = hzToMel(sttFMin)
        let highMel = hzToMel(sttFMax)
        let outSize = sttNFFT / 2 + 1

        let melPoints = (0..<(sttNMels + 2)).map { i -> Double in
            lowMel + (highMel - lowMel) * Double(i) / Double(sttNMels + 1)
        }
        let hzPoints = melPoints.map { melToHz($0) }
        let binPoints = hzPoints.map { Int(floor(Double(sttNFFT + 1) * $0 / Double(sttSampleRate))) }

        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: outSize), count: sttNMels)
        for m in 1..<(sttNMels + 1) {
            let left = binPoints[m - 1]
            let center = binPoints[m]
            let right = binPoints[m + 1]
            for k in left..<center where center > left {
                filterbank[m - 1][k] = Float(k - left) / Float(center - left)
            }
            for k in center..<right where right > center {
                filterbank[m - 1][k] = Float(right - k) / Float(right - center)
            }
        }
        return filterbank
    }

    // MARK: - STT Encoder/Decoder Inference

    /// Run Whisper encoder: [1, 80, 3000] → [1, 1500, 384]
    private func runEncoderInference(session: ORTSession, melSpectrogram: [[Float]]) throws -> [[Float]] {
        let nMels = melSpectrogram.count
        let nFrames = melSpectrogram[0].count
        let targetFrames = 3000

        // Flatten to [1, 80, 3000] with zero-padding
        var inputFloat = [Float](repeating: 0, count: nMels * targetFrames)
        for m in 0..<nMels {
            let actualFrames = min(nFrames, targetFrames)
            for t in 0..<actualFrames {
                inputFloat[m * targetFrames + t] = melSpectrogram[m][t]
            }
        }

        let inputData = NSMutableData(bytes: &inputFloat, length: inputFloat.count * MemoryLayout<Float>.size)
        let inputTensor = try ORTValue(
            tensorData: inputData,
            elementType: .float,
            shape: [1, NSNumber(value: nMels), NSNumber(value: targetFrames)]
        )

        let inputNames = try session.inputNames()
        let inputName = inputNames.first ?? "input_features"
        let outputNames = try session.outputNames()
        let outputNameSet = NSSet(array: outputNames) as! Set<String>
        let outputs = try session.run(withInputs: [inputName: inputTensor], outputNames: outputNameSet, runOptions: nil)

        guard let firstOutputName = outputNames.first,
              let outputValue = outputs[firstOutputName] else {
            throw OnnxRuntimeError.inferenceFailed("STT encoder returned no output")
        }

        let outputData = try outputValue.tensorData()
        let typeInfo = try outputValue.tensorTypeAndShapeInfo()
        let shape = typeInfo.shape
        let seqLen = shape.count >= 2 ? shape[1].intValue : 1500
        let hiddenDim = shape.count >= 3 ? shape[2].intValue : 384
        let floatBuffer = outputData.bytes.bindMemory(to: Float.self, capacity: seqLen * hiddenDim)

        var result = [[Float]](repeating: [Float](repeating: 0, count: hiddenDim), count: seqLen)
        for i in 0..<seqLen {
            for j in 0..<hiddenDim {
                result[i][j] = floatBuffer[i * hiddenDim + j]
            }
        }
        return result
    }

    /// Run Whisper decoder (autoregressive with KV cache)
    private func runDecoderInference(session: ORTSession, encoderOutput: [[Float]]) throws -> ([Int], Double) {
        let maxLength = 448
        let encoderSeqLen = encoderOutput.count
        let hiddenDim = encoderOutput[0].count

        // Flatten encoder output
        var encoderFloat = [Float](repeating: 0, count: encoderSeqLen * hiddenDim)
        for i in 0..<encoderSeqLen {
            for j in 0..<hiddenDim {
                encoderFloat[i * hiddenDim + j] = encoderOutput[i][j]
            }
        }
        let encoderData = NSMutableData(bytes: &encoderFloat, length: encoderFloat.count * MemoryLayout<Float>.size)
        let encoderTensor = try ORTValue(
            tensorData: encoderData,
            elementType: .float,
            shape: [1, NSNumber(value: encoderSeqLen), NSNumber(value: hiddenDim)]
        )

        let initialTokens = [tokenStartOfTranscript, tokenTranscribe, tokenNoTimestamps]
        var generatedTokens = initialTokens
        var decoderConfidence: Double = 0.0

        // KV cache: store output tensors to feed back as past_key_values
        var kvCacheValues: [String: ORTValue] = [:]

        for step in 0..<maxLength {
            let currentTokens: [Int]
            if step == 0 {
                currentTokens = initialTokens
            } else {
                currentTokens = [generatedTokens.last!]
            }
            let seqLen = currentTokens.count

            // input_ids [1, seqLen]
            var inputIds = currentTokens.map { Int64($0) }
            let inputIdsData = NSMutableData(bytes: &inputIds, length: inputIds.count * MemoryLayout<Int64>.size)
            let inputIdsTensor = try ORTValue(
                tensorData: inputIdsData,
                elementType: .int64,
                shape: [1, NSNumber(value: seqLen)]
            )

            // use_cache_branch: int8 tensor (0=false, 1=true) - ORT SDK has no bool type
            var useCacheByte: Int8 = step > 0 ? 1 : 0
            let useCacheData = NSMutableData(bytes: &useCacheByte, length: 1)
            let useCacheTensor = try ORTValue(
                tensorData: useCacheData,
                elementType: .int8,
                shape: [1]
            )

            // Build inputs
            var inputs: [String: ORTValue] = [
                "input_ids": inputIdsTensor,
                "encoder_hidden_states": encoderTensor,
                "use_cache_branch": useCacheTensor
            ]

            // Add KV cache
            for (key, value) in kvCacheValues {
                inputs[key] = value
            }

            let outputNames = try session.outputNames()
            let outputNameSet = NSSet(array: outputNames) as! Set<String>
            let outputs = try session.run(withInputs: inputs, outputNames: outputNameSet, runOptions: nil)

            // Extract logits (first output)
            guard let firstOutputName = outputNames.first,
                  let logitsValue = outputs[firstOutputName] else {
                throw OnnxRuntimeError.inferenceFailed("STT decoder returned no logits")
            }

            let logitsData = try logitsValue.tensorData()
            let logitsTypeInfo = try logitsValue.tensorTypeAndShapeInfo()
            let logitsShape = logitsTypeInfo.shape
            let vocabSize = logitsShape.count >= 3 ? logitsShape[2].intValue : 51865

            let logitsBuffer = logitsData.bytes.bindMemory(to: Float.self, capacity: seqLen * vocabSize)
            let lastOffset = (seqLen - 1) * vocabSize

            // Find argmax + softmax confidence
            var maxLogit = logitsBuffer[lastOffset]
            for i in 1..<vocabSize {
                if logitsBuffer[lastOffset + i] > maxLogit {
                    maxLogit = logitsBuffer[lastOffset + i]
                }
            }
            var expSum: Double = 0
            var maxToken = 0
            var maxExp: Double = 0
            for i in 0..<vocabSize {
                let expVal = exp(Double(logitsBuffer[lastOffset + i]) - Double(maxLogit))
                expSum += expVal
                if expVal > maxExp {
                    maxExp = expVal
                    maxToken = i
                }
            }
            let tokenConfidence = maxExp / expSum
            if step == 0 {
                decoderConfidence = tokenConfidence
            } else {
                decoderConfidence = (decoderConfidence * Double(generatedTokens.count) + tokenConfidence) / Double(generatedTokens.count + 1)
            }

            // Update KV cache: collect present.* outputs, feed back as past_key_values.*
            for (_, v) in kvCacheValues { /* ORTValue auto-released */ }
            kvCacheValues.removeAll()

            // Output indices: 0=logits, 1..N=present key/value pairs
            for outIdx in 1..<outputNames.count {
                guard let presentValue = outputs[outputNames[outIdx]] as? ORTValue else { continue }
                let pastKey = "past_key_values.\(outIdx - 1)"
                kvCacheValues[pastKey] = presentValue
            }

            // Check EOS
            if maxToken == tokenEndOfTranscript {
                print("OnnxRuntimeManager: STT EOS at step \(step)")
                break
            }

            generatedTokens.append(maxToken)
        }

        return (generatedTokens, decoderConfidence)
    }

    /// Decode token IDs to text using vocabulary
    private func decodeTokens(tokens: [Int]) -> String {
        guard !sttVocab.isEmpty else {
            return tokens.map { String($0) }.joined(separator: " ")
        }

        let skipTokens: Set<Int> = [
            tokenStartOfTranscript, tokenEndOfTranscript,
            tokenTranscribe, tokenTranslate, tokenNoTimestamps, tokenTimestampBegin
        ]

        var result = ""
        for tokenId in tokens {
            if skipTokens.contains(tokenId) { continue }
            if tokenId >= tokenTimestampBegin && tokenId <= 51864 {
                if !result.isEmpty && !result.hasSuffix(" ") { result += " " }
                continue
            }
            if let text = sttVocab[tokenId], !text.isEmpty {
                if text == "Ġ" {
                    result += " "
                } else if text == "Ċ" {
                    result += "\n"
                } else if text.hasPrefix("Ġ") {
                    result += " " + text.dropFirst()
                } else {
                    result += text
                }
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
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
    /// BGE model outputs [batch, seq_len, hidden_dim] - applies mean pooling
    private func extractEmbedding(from outputValue: ORTValue) throws -> [Double] {
        let outputData = try outputValue.tensorData()
        let floatCount = outputData.count / MemoryLayout<Float>.size
        let bytes = outputData.bytes.bindMemory(to: Float.self, capacity: floatCount)

        let typeAndShapeInfo = try outputValue.tensorTypeAndShapeInfo()
        let shape = typeAndShapeInfo.shape

        if shape.count >= 3 {
            // [batch, seq_len, hidden_dim] - mean pooling across seq_len
            let seqLen = shape[1].intValue
            let hiddenDim = shape[2].intValue
            print("OnnxRuntimeManager: Embedding 3D output: [\(shape[0]), \(seqLen), \(hiddenDim)]")

            var pooled = [Double](repeating: 0.0, count: hiddenDim)
            for s in 0..<seqLen {
                let offset = s * hiddenDim
                for h in 0..<hiddenDim {
                    pooled[h] += Double(bytes[offset + h])
                }
            }
            let seqLenDouble = Double(seqLen)
            for h in 0..<hiddenDim {
                pooled[h] /= seqLenDouble
            }
            return pooled
        } else if shape.count >= 2 {
            // [batch, hidden_dim]
            let hiddenDim = shape[1].intValue
            let count = min(hiddenDim, floatCount)
            print("OnnxRuntimeManager: Embedding 2D output: [\(shape[0]), \(hiddenDim)]")
            return (0..<count).map { Double(bytes[$0]) }
        } else {
            // Flat array fallback
            let count = min(384, floatCount)
            print("OnnxRuntimeManager: Embedding flat output: [\(count)]")
            return (0..<count).map { Double(bytes[$0]) }
        }
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
        var totalConf: Double = 0.0
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

            // Compute softmax for confidence (numerical stability: subtract max)
            var expSum: Double = 0.0
            for c in 0..<numClasses {
                expSum += exp(Double(floatBuffer[offset + c]) - Double(maxVal))
            }
            let maxProb = 1.0 / expSum  // exp(maxVal - maxVal) / expSum
            totalConf += maxProb
            charCount += 1
            lastIdx = maxIdx
        }

        let confidence = charCount > 0 ? totalConf / Double(charCount) : 0.0
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
    private func imageToRgbFloatBuffer(_ image: UIImage) throws -> [Float] {
        guard let cgImage = image.cgImage else {
            throw OnnxRuntimeError.imageDecodeFailed
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
