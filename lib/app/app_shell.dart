import 'package:flutter/material.dart';

import '../pages/conversation_shell.dart';
import '../pages/model_load_page.dart';
import '../pages/models_page.dart';
import '../pages/settings_page.dart';
import '../pages/status_page.dart';
import '../pages/test_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.pages});

  final List<Widget>? pages;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _defaultPages = [
    StatusPage(),
    ModelLoadPage(),
    ConversationShell(),
    TestPage(),
    ModelsPage(),
    SettingsPage(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(icon: Icon(Icons.info_outline), label: '状态'),
    NavigationDestination(icon: Icon(Icons.folder_open), label: '加载'),
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: '对话'),
    NavigationDestination(icon: Icon(Icons.play_circle_outline), label: '测试'),
    NavigationDestination(icon: Icon(Icons.apps), label: '模型'),
    NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ?? _defaultPages;
    assert(
      pages.length == _destinations.length,
      'AppShell pages count must match navigation destinations.',
    );

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: _destinations,
      ),
    );
  }
}
