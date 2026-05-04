import '../models/model_loader_exception.dart';

String buildTestModelNotLoadedStatus({required String taskLabel}) {
  final code = ModelLoaderErrorCode.MODEL_LOAD_FAILED.code;
  return '❌ [$code] $taskLabel 模型未加载\n\n先到"加载"页面加载 $taskLabel 模型';
}

String buildTestInferenceFailedStatus({
  required String taskLabel,
  String? reason,
}) {
  final code = ModelLoaderErrorCode.INFERENCE_FAILED.code;
  final reasonText = reason != null && reason.isNotEmpty ? '\n原因: $reason' : '';
  return '❌ [$code] $taskLabel 推理失败$reasonText\n请查看日志获取详细信息';
}

String buildTestRuntimeUnavailableStatus({
  required String taskLabel,
  String? reason,
}) {
  final code = ModelLoaderErrorCode.RUNTIME_NOT_AVAILABLE.code;
  final reasonText = reason != null && reason.isNotEmpty ? '\n原因: $reason' : '';
  return '⚠️ [$code] $taskLabel 运行时当前不可用$reasonText\n请切换平台或补齐该能力的原生实现';
}
