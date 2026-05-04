import 'dart:typed_data';

/// Content block types for structured conversation display.
///
/// Provides polymorphic content rendering beyond plain text,
/// enabling the UI to display embeddings, OCR results, errors,
/// status indicators, and metrics with appropriate formatting.
sealed class ContentBlock {
  const ContentBlock();
}

/// Plain text content.
class TextBlock extends ContentBlock {
  final String text;
  const TextBlock(this.text);
}

/// Error display with optional error code.
class ErrorBlock extends ContentBlock {
  final String message;
  final String? code;
  const ErrorBlock(this.message, {this.code});
}

/// Transient status message (e.g., "正在加载...").
class StatusBlock extends ContentBlock {
  final String message;
  final bool isTransient;
  const StatusBlock(this.message, {this.isTransient = false});
}

/// Embedding vector preview.
class EmbeddingBlock extends ContentBlock {
  final int dimension;
  final List<double> preview;
  const EmbeddingBlock({required this.dimension, required this.preview});
}

/// OCR recognition result.
class OCRBlockDisplay extends ContentBlock {
  final String text;
  final double confidence;
  final Uint8List? imageBytes;
  const OCRBlockDisplay({
    required this.text,
    required this.confidence,
    this.imageBytes,
  });
}

/// Key-value metric display (e.g., "耗时: 120ms").
class MetricBlock extends ContentBlock {
  final String label;
  final String value;
  const MetricBlock(this.label, this.value);
}
