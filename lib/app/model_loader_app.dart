import 'package:flutter/material.dart';

import 'app_shell.dart';

class ModelLoaderApp extends StatelessWidget {
  const ModelLoaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ModelLoader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
