import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class CustomerAuthProvider with ChangeNotifier {
  static const _keyToken = 'customer_app_token';
  static const _keyName  = 'customer_name';
  static const _keyEmail = 'customer_email';
  static const _keyUid   = 'customer_uid';

  String? _appToken;
  String  _displayName = '';
  String  _email       = '';
  String  _uid         = '';
  bool    _loading     = false;
  String? _error;

  bool    get isLoggedIn   => _appToken != null;
  String  get displayName  => _displayName;
  String  get email        => _email;
  String  get uid          => _uid;
  String? get appToken     => _appToken;
  bool    get loading      => _loading;
  String? get error        => _error;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token != null) {
      _appToken    = token;
      _displayName = prefs.getString(_keyName)  ?? '';
      _email       = prefs.getString(_keyEmail) ?? '';
      _uid         = prefs.getString(_keyUid)   ?? '';
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _loading = false;
        notifyListeners();
        return false; // usuario canceló
      }
      final googleAuth = await googleUser.authentication;
      // Usa el Google ID token directamente (sin signInWithCredential que
      // requiere dominio registrado en Firebase y devuelve HTML de error)
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('No se pudo obtener el token de Google');

      final result   = await ApiService.loginWithGoogle(idToken);
      _appToken      = result['token'] as String;
      final customer = result['customer'] as Map<String, dynamic>;
      _displayName   = (customer['display_name'] as String?) ?? '';
      _email         = (customer['email']        as String?) ?? '';
      _uid           = (customer['firebase_uid'] as String?) ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, _appToken!);
      await prefs.setString(_keyName,  _displayName);
      await prefs.setString(_keyEmail, _email);
      await prefs.setString(_keyUid,   _uid);

      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    _appToken    = null;
    _displayName = '';
    _email       = '';
    _uid         = '';
    final prefs  = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUid);
    notifyListeners();
  }
}
