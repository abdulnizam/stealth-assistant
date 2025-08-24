import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _kBaseUrl = 'api_base_url';
  static const _kApiKey = 'api_key';
  static const _kModel = 'llm_model'; // NEW

  static Future<void> save({
    required String baseUrl,
    required String apiKey,
    required String model, // NEW
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, baseUrl);
    await prefs.setString(_kApiKey, apiKey);
    await prefs.setString(_kModel, model);
  }

  /// Returns (baseUrl, apiKey, model)
  static Future<(String, String, String)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_kBaseUrl) ?? '';
    final key = prefs.getString(_kApiKey) ?? '';
    final model = prefs.getString(_kModel) ?? 'gemma:7b-instruct';
    return (base, key, model);
  }
}
