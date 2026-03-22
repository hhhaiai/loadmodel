import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_loader_exception.dart';
import 'package:model_loader/pages/model_load_page.dart';

void main() {
  group('ModelLoadPage status text builders', () {
    test(
      'missing-asset status includes MODEL_NOT_FOUND code and model directory',
      () {
        final text = buildMissingAssetStatus(
          modelDir: 'whisper',
          taskLabel: 'STT',
          requiredFiles: const ['model.onnx'],
        );

        expect(
          text,
          contains('[${ModelLoaderErrorCode.MODEL_NOT_FOUND.code}]'),
        );
        expect(text, contains('assets/models/whisper/'));
        expect(text, contains('- model.onnx'));
      },
    );

    test('missing-asset status renders multiple required files list', () {
      final text = buildMissingAssetStatus(
        modelDir: 'bge-small',
        taskLabel: 'Embedding',
        requiredFiles: const ['model.onnx', 'tokenizer.json'],
      );

      expect(text, contains('Embedding'));
      expect(text, contains('- model.onnx'));
      expect(text, contains('- tokenizer.json'));
    });

    test(
      'runtime-load-failed status includes MODEL_LOAD_FAILED code and reason',
      () {
        final text = buildRuntimeLoadFailedStatus(
          taskLabel: 'OCR',
          reason:
              'PlatformException(LOAD_ERROR, Native runtime failed, null, null)',
        );

        expect(
          text,
          contains('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
        );
        expect(text, contains('OCR'));
        expect(text, contains('原因: PlatformException('));
      },
    );

    test('runtime-load-failed status omits reason when empty', () {
      final text = buildRuntimeLoadFailedStatus(taskLabel: 'STT');

      expect(
        text,
        contains('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
      );
      expect(text, contains('STT'));
      expect(text.contains('原因:'), isFalse);
    });

    test(
      'runtime-unavailable status includes RUNTIME_NOT_AVAILABLE code and reason',
      () {
        final text = buildRuntimeUnavailableStatus(
          taskLabel: 'TTS',
          reason: 'runtime bridge not implemented',
        );

        expect(
          text,
          contains('[${ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE.code}]'),
        );
        expect(text, contains('TTS 运行时当前不可用'));
        expect(text, contains('原因: runtime bridge not implemented'));
      },
    );

    test(
      'missing-llm-asset status includes MODEL_NOT_FOUND code and file path',
      () {
        final text = buildMissingLlmAssetStatus(
          assetPath:
              'assets/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
        );

        expect(
          text,
          contains('[${ModelLoaderErrorCode.MODEL_NOT_FOUND.code}]'),
        );
        expect(text, contains('LLM 模型文件缺失'));
        expect(
          text,
          contains(
            'assets/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
          ),
        );
      },
    );
  });
}
