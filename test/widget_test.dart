// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stealth_assistant/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:stealth_assistant/services/storage_service.dart';
import 'package:stealth_assistant/providers/theme_provider.dart';
import 'package:stealth_assistant/models/message.dart';

class MockStorageService extends ChangeNotifier implements StorageService {
  @override
  bool get isReady => true;
  @override
  List<Message> get messages => <Message>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> addMessage(role, content) async {}
  @override
  Future<void> clear() async {}
}

class MockThemeProvider extends ChangeNotifier implements ThemeProvider {
  Color _primaryColor = colorOptions[0];
  ThemeMode _themeMode = ThemeMode.system;
  @override
  Color get primaryColor => _primaryColor;
  @override
  ThemeMode get themeMode => _themeMode;
  @override
  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  @override
  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }
}

void main() {
  testWidgets('App renders and theme can be changed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(
              create: (_) => MockThemeProvider()),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should find the Theme dropdown
    expect(find.text('Theme'), findsWidgets);

    // Should find the Primary Color section
    expect(find.text('Primary Color'), findsOneWidget);
    // Tap the first color option
    final colorCircle = find.byType(CircleAvatar).first;
    await tester.tap(colorCircle);
    await tester.pumpAndSettle();
    // Should show check icon in the selected color
    expect(find.byIcon(Icons.check), findsWidgets);
  });
}
