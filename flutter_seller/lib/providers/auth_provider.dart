import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

class AuthProvider with ChangeNotifier {
  bool    _loggedIn   = false;
  String  _user       = '';
  String  _token      = '';
  String  _role       = 'seller';
  List<int> _branchIds = [];
  bool    _loading    = false;
  String? _error;

  bool      get loggedIn   => _loggedIn;
  String    get user       => _user;
  String    get token      => _token;
  String    get role       => _role;
  List<int> get branchIds  => _branchIds;
  bool      get loading    => _loading;
  String?   get error      => _error;

  bool get isOwner => _role == 'owner';
  bool get isAdmin => _role == 'admin' || _role == 'owner';

  Future<void> tryAutoLogin() async {
    final saved = await SettingsService.getSavedAuth();
    if (saved['user'] != null && saved['token'] != null) {
      _user     = saved['user']!;
      _token    = saved['token']!;
      _role     = saved['role'] ?? 'seller';
      _loggedIn = true;
      ApiService.setAuthToken(_token);
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      final result = await ApiService.login(username, password);
      _user     = result['user'] as String;
      _token    = result['token'] as String;
      _role     = (result['role'] as String?) ?? 'seller';
      _loggedIn = true;
      ApiService.setAuthToken(_token);
      await SettingsService.saveAuth(_user, _token, role: _role);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _loading = false;
        notifyListeners();
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('No se obtuvo token de Google');

      // Enviamos el Google ID token directamente al backend.
      // El backend lo verifica con tokeninfo de Google — sin restricción de dominio/IP.
      final result = await ApiService.loginWithGoogleSeller(idToken);
      final seller = result['seller'] as Map<String, dynamic>;
      _user       = (seller['email'] as String?) ?? '';
      _token      = result['token'] as String;
      _role       = (seller['role'] as String?) ?? 'seller';
      _branchIds  = ((seller['branches'] as List<dynamic>?)
              ?.map((b) => (b as Map<String, dynamic>)['id'] as int)
              .toList()) ??
          [];
      _loggedIn = true;
      ApiService.setAuthToken(_token);
      await SettingsService.saveAuth(_user, _token, role: _role);
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
    await GoogleSignIn().signOut().catchError((_) {});
    await fb.FirebaseAuth.instance.signOut().catchError((_) {});
    _loggedIn  = false;
    _user      = '';
    _token     = '';
    _role      = 'seller';
    _branchIds = [];
    _error     = null;
    ApiService.setAuthToken(null);
    await SettingsService.clearAuth();
    notifyListeners();
  }
}
