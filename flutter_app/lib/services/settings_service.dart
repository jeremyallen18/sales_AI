import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Persiste la URL del servidor y la expone a ApiConfig.
class SettingsService {
  static const String _key = 'server_base_url';
  static const String defaultBaseUrl = 'http://128.4.1.148:5000';

  /// Llama en main() antes de runApp().
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    ApiConfig.setBaseUrl(
      (saved != null && saved.isNotEmpty) ? saved : defaultBaseUrl,
    );
  }

  static String get currentBaseUrl => ApiConfig.baseUrl;

  static Future<void> saveBaseUrl(String url) async {
    ApiConfig.setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url);
  }

  static Future<void> resetToDefault() =>
      saveBaseUrl(defaultBaseUrl);
}
