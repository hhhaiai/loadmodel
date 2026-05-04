import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/models/model_loader_exception.dart';
import 'package:model_loader/utils/status_messages.dart';

void main() {
  group('TestPage status text builders', () {
    test('model-not-loaded status includes MODEL_LOAD_FAILED code', () {
      final text = buildTestModelNotLoadedStatus(taskLabel: 'LLM');

      expect(
        text,
        contains('[${ModelLoaderErrorCode.MODEL_LOAD_FAILED.code}]'),
      );
      expect(text, contains('LLM 模型未加载'));
      expect(text, contains('先到"加载"页面加载 LLM 模型'));
    });

    test(
      'inference-failed status includes INFERENCE_FAILED code and reason',
      () {
        final text = buildTestInferenceFailedStatus(
          taskLabel: 'STT',
          reason:
              'PlatformException(INFERENCE_ERROR, decode failed, null, null)',
        );

        expect(
          text,
          contains('[${ModelLoaderErrorCode.INFERENCE_FAILED.code}]'),
        );
        expect(text, contains('STT 推理失败'));
        expect(text, contains('原因: PlatformException('));
      },
    );

    test('inference-failed status omits reason when empty', () {
      final text = buildTestInferenceFailedStatus(taskLabel: 'OCR');

      expect(text, contains('[${ModelLoaderErrorCode.INFERENCE_FAILED.code}]'));
      expect(text, contains('OCR 推理失败'));
      expect(text.contains('原因:'), isFalse);
    });

    test(
      'runtime-unavailable status includes RUNTIME_NOT_AVAILABLE code and reason',
      () {
        final text = buildTestRuntimeUnavailableStatus(
          taskLabel: 'TTS',
          reason: 'platform implementation missing',
        );

        expect(
          text,
          contains('[${ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE.code}]'),
        );
        expect(text, contains('TTS 运行时当前不可用'));
        expect(text, contains('原因: platform implementation missing'));
      },
    );
  });
}
