import 'package:flutter/material.dart';

// The app's theme manager — controls dark mode switching and supplies light/dark themes
class ThemeProvider with ChangeNotifier {
  bool _isDark = false;

  // It lets screens check whether dark mode is currently turned on
  bool get isDark => _isDark;

  // It provides our standard light theme configuration
  ThemeData get lightTheme => ThemeData.light();

  // It provides our standard dark theme configuration
  ThemeData get darkTheme => ThemeData.dark();

  // It flips the dark mode flag and tells the app to re-render with the new theme
  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}