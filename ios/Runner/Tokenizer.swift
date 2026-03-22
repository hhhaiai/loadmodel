//
//  Tokenizer.swift
//  ModelLoader
//
//  WordPiece Tokenizer implementation for BGE/Transformer models
//

import Foundation

/// WordPiece Tokenizer for BGE models
class WordPieceTokenizer {

    private var vocab: [String: Int] = [:]
    private var unknownToken: String = "[UNK]"
    private var maxInputCharsPerWord: Int = 100

    init() {}

    /// Load vocabulary from tokenizer.json
    func loadVocabulary(from path: String) throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)

        // Try to parse as tokenizer.json
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let vocabDict = json["model"] as? [String: Any],
           let vocabList = vocabDict["vocab"] as? [String: Any] {
            // HuggingFace format
            for (token, index) in vocabList {
                if let idx = index as? Int {
                    vocab[token] = idx
                }
            }
        } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let model = json["model"] as? [String: Any],
                  let tokenizer = json["tokenizer"] as? [String: Any] {
            // Full tokenizer.json format
            if let vocabWithIndex = tokenizer["model"] as? [String: Any],
               let vocabDict = vocabWithIndex["vocab"] as? [String: Any] {
                for (token, index) in vocabDict {
                    if let idx = index as? Int {
                        vocab[token] = idx
                    }
                }
            }
        } else {
            // Try simple text format (one token per line)
            let content = String(data: data, encoding: .utf8) ?? ""
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                let token = line.trimmingCharacters(in: .whitespaces)
                if !token.isEmpty {
                    vocab[token] = index
                }
            }
        }

        print("Tokenizer: loaded \(vocab.count) tokens")
    }

    /// Load vocabulary from separate vocab.txt file
    func loadVocabularyFromVocabFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let token = line.trimmingCharacters(in: .whitespaces)
            if !token.isEmpty {
                vocab[token] = index
            }
        }

        print("Tokenizer: loaded \(vocab.count) tokens from vocab file")
    }

    /// Tokenize text into WordPiece tokens
    func tokenize(_ text: String) -> [String] {
        let text = text.lowercased()
        var outputTokens: [String] = []

        let words = text.components(separatedBy: .whitespaces)
        for word in words {
            if word.isEmpty { continue }

            var chars = Array(word)
            var isBad = false
            var start = 0
            var subTokens: [String] = []

            while start < chars.count {
                var end = min(chars.count, start + maxInputCharsPerWord)
                var curSubstr = ""

                while end > start {
                    let substr = String(chars[start..<end])
                    if start > 0 {
                        curSubstr = "##" + substr
                    } else {
                        curSubstr = substr
                    }

                    if vocab[curSubstr] != nil {
                        break
                    }
                    end -= 1
                }

                if start == end {
                    isBad = true
                    break
                }

                subTokens.append(curSubstr)
                start = end
            }

            if isBad {
                outputTokens.append(unknownToken)
            } else {
                outputTokens.append(contentsOf: subTokens)
            }
        }

        return outputTokens
    }

    /// Convert tokens to token IDs
    func convertTokensToIds(_ tokens: [String]) -> [Int] {
        return tokens.map { vocab[$0] ?? vocab[unknownToken] ?? 0 }
    }

    /// Full tokenization: text to IDs
    func encode(_ text: String) -> [Int] {
        let tokens = tokenize(text)
        return convertTokensToIds(tokens)
    }
}

/// Basic tokenization utilities
class BasicTokenizer {

    private var doLowerCase: Bool = true

    init(doLowerCase: Bool = true) {
        self.doLowerCase = doLowerCase
    }

    /// Tokenize by whitespace and punctuation
    func tokenize(_ text: String) -> [String] {
        var text = text
        if doLowerCase {
            text = text.lowercased()
        }

        // Simple whitespace tokenization
        // For production, add more sophisticated handling
        let tokens = text.components(separatedBy: .whitespaces)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        return tokens
    }
}
