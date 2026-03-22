// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 测试 Embedding 模型加载
Future<void> main() async {
  print('=== Embedding 端到端测试 ===\n');

  // 1. 测试 AssetHelper
  print('1. 测试 AssetHelper...');
  final cacheDir = await getApplicationCacheDirectory();
  print('   缓存目录: ${cacheDir.path}');

  // 列出 assets 中的模型文件
  print('\n2. 检查 assets 中的模型文件:');
  final manifest = await rootBundle.loadString('AssetManifest.json');
  print('   Asset manifest (bge-small):');

  // 查找 bge-small 相关文件
  final assets = manifest.split('bge-small').join('\n   bge-small');
  print('   $assets\n');

  // 3. 测试模型文件复制
  print('3. 测试模型文件复制:');
  final modelFile = File('${cacheDir.path}/models/bge-small/model.onnx');
  final tokenizerFile = File('${cacheDir.path}/models/bge-small/tokenizer.json');

  if (await modelFile.exists()) {
    print('   ✅ model.onnx 存在 (${await modelFile.length()} bytes)');
  } else {
    print('   ⚠️ model.onnx 不存在，需要从 assets 复制');
  }

  if (await tokenizerFile.exists()) {
    print('   ✅ tokenizer.json 存在');
  } else {
    print('   ⚠️ tokenizer.json 不存在，需要从 assets 复制');
  }

  print('\n=== 测试完成 ===');
  print('在模拟器中手动测试步骤:');
  print('1. 打开应用');
  print('2. 进入"加载"页面');
  print('3. 选择 "Embedding (文本向量)"');
  print('4. 点击"加载模型"');
  print('5. 进入"测试"页面测试向量生成');
}
