import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// List of color options for user to pick
const List<Color> colorOptions = [
  Color(0xFF4F46E5), // Indigo
  Colors.deepPurple,
  Colors.teal,
  Colors.pink,
  Colors.orange,
  Colors.green,
  Colors.blue,
  Colors.red,
];

class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = colorOptions[0];
  Color get primaryColor => _primaryColor;

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
    notifyListeners();
  }
}
