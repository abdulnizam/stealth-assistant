import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _kBaseUrl = 'llm_base_url';
  static const _kApiKey = 'llm_api_key';
  static const _kModel = 'llm_model';
  static const _kProvider = 'llm_provider'; // e.g. 'openai', 'anthropic', etc.

  static Future<void> save({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String provider, // e.g. 'openai', 'anthropic', etc.
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, baseUrl);
    await prefs.setString(_kApiKey, apiKey);
    await prefs.setString(_kModel, model);
    await prefs.setString(_kProvider, provider);
  }

  /// Returns (baseUrl, apiKey, model, provider)
  static Future<(String, String, String, String)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_kBaseUrl) ?? '';
    final key = prefs.getString(_kApiKey) ?? '';
    final model = prefs.getString(_kModel) ?? 'gemma:7b-instruct';
    final provider = prefs.getString(_kProvider) ?? 'local';
    return (base, key, model, provider);
  }
}
