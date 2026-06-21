import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el modo de tema (claro/oscuro/sistema) y lo persiste en SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Crea e inicializa el provider leyendo la preferencia guardada.
  /// Llamar antes de runApp().
  static Future<ThemeProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final provider = ThemeProvider();
    if (stored == 'dark') {
      provider._mode = ThemeMode.dark;
    } else if (stored == 'light') {
      provider._mode = ThemeMode.light;
    }
    return provider;
  }

  /// Cambia el modo y lo persiste.
  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Alterna entre dark y light (si está en system, lo trata como light).
  Future<void> toggle() => setMode(
        _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );
}
