import 'package:flutter/material.dart';

/// Global navigation controller for AppShell page switching
class AppNavigationController extends ChangeNotifier {
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void navigateTo(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }
}

/// Global instance for cross-page navigation
final appNavigationController = AppNavigationController();