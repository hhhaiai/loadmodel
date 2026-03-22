import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'app/model_loader_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapModelLoaderApp();
  runApp(const ModelLoaderApp());
}


