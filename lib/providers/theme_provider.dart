import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// List of color options for user to pick
const List<Color> colorOptions = [
  Colors.deepPurple,
  Colors.teal,
  Colors.pink,
  Colors.orange,
  Colors.green,
  Colors.blue,
  Colors.red,
  Colors.black
];

class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = colorOptions[0];
  Color _pathColor = colorOptions[0];
  Color _codeColor = colorOptions[0];
  Color get primaryColor => _primaryColor;
  Color get pathColor => _pathColor;
  Color get codeColor => _codeColor;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', mode.name);
  }

  void setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('primary_color', color.value);
  }

  void setPathColor(Color color) async {
    _pathColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('path_color', color.value);
  }

  void setCodeColor(Color color) async {
    _codeColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('code_color', color.value);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode');
    if (mode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (mode == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    final colorValue = prefs.getInt('primary_color');
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
    }
    final pathColorValue = prefs.getInt('path_color');
    if (pathColorValue != null) {
      _pathColor = Color(pathColorValue);
    }
    final codeColorValue = prefs.getInt('code_color');
    if (codeColorValue != null) {
      _codeColor = Color(codeColorValue);
    }
    notifyListeners();
  }
}
