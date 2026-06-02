import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SettingsService {
  static const String _keyUrl = 'server_base_url';
  static const String _keyUser = 'auth_user';
  static const String _keyToken = 'auth_token';
  static const String defaultBaseUrl = 'http://128.4.1.148:5000';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyUrl);
    ApiConfig.setBaseUrl(
      (saved != null && saved.isNotEmpty) ? saved : defaultBaseUrl,
    );
  }

  static String get currentBaseUrl => ApiConfig.baseUrl;

  static Future<void> saveBaseUrl(String url) async {
    ApiConfig.setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url);
  }

  static Future<void> saveAuth(String user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, user);
    await prefs.setString(_keyToken, token);
  }

  static Future<Map<String, String?>> getSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user': prefs.getString(_keyUser),
      'token': prefs.getString(_keyToken),
    };
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await prefs.remove(_keyToken);
  }

  static Future<void> resetToDefault() => saveBaseUrl(defaultBaseUrl);
}
