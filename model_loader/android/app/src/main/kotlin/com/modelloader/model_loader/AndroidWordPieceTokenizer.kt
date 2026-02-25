//
//  AndroidWordPieceTokenizer.kt
//  ModelLoader
//
//  WordPiece Tokenizer implementation for BGE/Transformer models on Android
//

package com.modelloader.model_loader

import android.util.Log
import org.json.JSONObject
import java.io.File
import java.io.FileReader
import java.io.BufferedReader

/**
 * WordPiece Tokenizer for BGE models on Android
 */
class AndroidWordPieceTokenizer {

    private val vocab = mutableMapOf<String, Int>()
    private val unknownToken = "[UNK]"
    private val maxInputCharsPerWord = 100
    private val tag = "WordPieceTokenizer"

    /**
     * Load vocabulary from tokenizer.json
     */
    fun loadVocabulary(path: String) {
        try {
            val file = File(path)
            if (!file.exists()) {
                Log.w(tag, "Tokenizer file not found: $path")
                return
            }

            val content = file.readText()
            val json = JSONObject(content)

            // Try HuggingFace format: model.vocab
            if (json.has("model")) {
                val model = json.getJSONObject("model")
                if (model.has("vocab")) {
                    val vocabJson = model.getJSONObject("vocab")
                    vocabJson.keys().forEach { token ->
                        vocab[token] = vocabJson.getInt(token)
                    }
                }
            }
            // Try full tokenizer.json format
            else if (json.has("tokenizer")) {
                val tokenizer = json.getJSONObject("tokenizer")
                if (tokenizer.has("model")) {
                    val model = tokenizer.getJSONObject("model")
                    if (model.has("vocab")) {
                        val vocabJson = model.getJSONObject("vocab")
                        vocabJson.keys().forEach { token ->
                            vocab[token] = vocabJson.getInt(token)
                        }
                    }
                }
            }

            Log.i(tag, "Loaded ${vocab.size} tokens from vocabulary")
        } catch (e: Exception) {
            Log.e(tag, "Error loading vocabulary: ${e.message}")
            // Try fallback: load from vocab.txt
            tryLoadVocabFile(path)
        }
    }

    /**
     * Try loading from vocab.txt file
     */
    private fun tryLoadVocabFile(path: String) {
        try {
            val vocabPath = path.replace("tokenizer.json", "vocab.txt")
            val file = File(vocabPath)
            if (!file.exists()) return

            BufferedReader(FileReader(file)).use { reader ->
                var line: String?
                var index = 0
                while (reader.readLine().also { line = it } != null) {
                    line?.let {
                        val token = it.trim()
                        if (token.isNotEmpty()) {
                            vocab[token] = index++
                        }
                    }
                }
            }
            Log.i(tag, "Loaded ${vocab.size} tokens from vocab file")
        } catch (e: Exception) {
            Log.e(tag, "Error loading vocab file: ${e.message}")
        }
    }

    /**
     * Tokenize text into WordPiece tokens
     */
    fun tokenize(text: String): List<String> {
        val lowerText = text.lowercase()
        val outputTokens = mutableListOf<String>()

        val words = lowerText.split("\\s+".toRegex())
        for (word in words) {
            if (word.isEmpty()) continue

            val chars = word.toCharArray()
            var isBad = false
            var start = 0
            val subTokens = mutableListOf<String>()

            while (start < chars.size) {
                var end = minOf(chars.size, start + maxInputCharsPerWord)
                var curSubstr = ""
                var found = false

                while (end > start) {
                    val substr = String(chars, start, end - start)
                    curSubstr = if (start > 0) "##$substr" else substr

                    if (vocab.containsKey(curSubstr)) {
                        found = true
                        break
                    }
                    end--
                }

                if (!found) {
                    isBad = true
                    break
                }

                subTokens.add(curSubstr)
                start = end
            }

            if (isBad) {
                outputTokens.add(unknownToken)
            } else {
                outputTokens.addAll(subTokens)
            }
        }

        return outputTokens
    }

    /**
     * Convert tokens to token IDs
     */
    fun convertTokensToIds(tokens: List<String>): List<Int> {
        return tokens.map { vocab[it] ?: vocab[unknownToken] ?: 0 }
    }

    /**
     * Full tokenization: text to IDs
     */
    fun encode(text: String): List<Int> {
        val tokens = tokenize(text)
        return convertTokensToIds(tokens)
    }

    /**
     * Get vocabulary size
     */
    fun getVocabSize(): Int = vocab.size
}
