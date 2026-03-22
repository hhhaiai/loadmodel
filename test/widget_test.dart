import 'package:flutter_test/flutter_test.dart';
import 'package:model_loader/model_loader.dart';
import 'package:model_loader/models/model_type.dart';
import 'package:model_loader/utils/logger.dart';
import 'package:model_loader/runtime/runtime_factory.dart';

void main() {
  group('ModelLoader 初始化测试', () {
    setUpAll(() async {
      // 初始化 SDK
      await ModelLoader.initialize(
        config: const ModelLoaderConfig(
          enableRemoteModels: false,
          logLevel: LogLevel.warning,
          autoSelectRuntime: true,
        ),
      );
    });

    test('ModelLoader 单例在初始化后可用', () {
      expect(ModelLoader.instance.isInitialized, isTrue);
    });

    test('ModelLoader 平台信息正确', () {
      final ml = ModelLoader.instance;
      expect(ml.platform, isNotNull);
      expect(ml.platform.name, isNotEmpty);
    });

    test('ModelLoader 配置可访问', () {
      final ml = ModelLoader.instance;
      expect(ml.config, isNotNull);
      expect(ml.config.enableRemoteModels, isFalse);
    });

    test('ModelLoader 各运行时可访问', () {
      final ml = ModelLoader.instance;
      expect(ml.llm, isNotNull);
      expect(ml.ocr, isNotNull);
      expect(ml.tts, isNotNull);
      expect(ml.stt, isNotNull);
      expect(ml.embedding, isNotNull);
    });

    test('ModelManager 可访问', () {
      final ml = ModelLoader.instance;
      expect(ml.models, isNotNull);
    });

    test('ConfigManager 可访问', () {
      final ml = ModelLoader.instance;
      expect(ml.configManager, isNotNull);
    });
  });

  group('ModelType 测试', () {
    test('ModelType 枚举包含预期类型', () {
      expect(ModelType.values, contains(ModelType.llm));
      expect(ModelType.values, contains(ModelType.embedding));
      expect(ModelType.values, contains(ModelType.ocr));
      expect(ModelType.values, contains(ModelType.stt));
      expect(ModelType.values, contains(ModelType.tts));
      expect(ModelType.values, contains(ModelType.classification));
    });
  });

  group('PlatformInfo 测试', () {
    test('PlatformInfo 基本属性存在', () {
      final platform = PlatformInfo.current();
      expect(platform.name, isNotEmpty);
      expect(platform.isMobile != platform.isDesktop, isTrue);
    });
  });

  group('ModelLoaderConfig 测试', () {
    test('默认配置值正确', () {
      const config = ModelLoaderConfig();
      expect(config.enableRemoteModels, isFalse);
      expect(config.logLevel, equals(LogLevel.info));
      expect(config.autoSelectRuntime, isTrue);
    });

    test('自定义配置可覆盖默认值', () {
      const config = ModelLoaderConfig(
        enableRemoteModels: false,
        logLevel: LogLevel.debug,
        autoSelectRuntime: false,
      );
      expect(config.enableRemoteModels, isFalse);
      expect(config.logLevel, equals(LogLevel.debug));
      expect(config.autoSelectRuntime, isFalse);
    });

    test('cacheDir 有默认值', () {
      const config = ModelLoaderConfig();
      expect(config.cacheDir, isNotEmpty);
    });
  });
}
