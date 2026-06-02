import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

class AuthProvider with ChangeNotifier {
  bool _loggedIn = false;
  String _user = '';
  String _token = '';
  bool _loading = false;
  String? _error;

  bool get loggedIn => _loggedIn;
  String get user => _user;
  String get token => _token;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    final saved = await SettingsService.getSavedAuth();
    if (saved['user'] != null && saved['token'] != null) {
      _user = saved['user']!;
      _token = saved['token']!;
      _loggedIn = true;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await ApiService.login(username, password);
      _user = result['user'] as String;
      _token = result['token'] as String;
      _loggedIn = true;
      await SettingsService.saveAuth(_user, _token);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _loggedIn = false;
    _user = '';
    _token = '';
    _error = null;
    await SettingsService.clearAuth();
    notifyListeners();
  }
}
