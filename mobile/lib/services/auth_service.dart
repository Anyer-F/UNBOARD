import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/models/auth_user.dart';
import '../core/network/api_client.dart';

class AuthService extends ChangeNotifier {
  final ApiService _api = ApiService();

  AuthUser? _currentUser;
  bool _isLoading = false;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(jsonDecode(userJson));
        // Validar la expiración del token JWT (claim 'exp'):
        // si expiró, cerrar sesión y volver al login.
        final token = _currentUser?.token;
        if (token != null && _tokenExpirado(token)) {
          await logout();
          return;
        }
        await _api.setToken(_currentUser?.token);
        notifyListeners();
      } catch (e) {
        await logout();
      }
    }
  }

  /// Decodifica el claim `exp` de un JWT y retorna `true` si ya expiró.
  bool _tokenExpirado(String token) {
    try {
      final partes = token.split('.');
      if (partes.length != 3) return true;
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(partes[1])))
              as Map<String, dynamic>;
      final exp = payload['exp'] as num?;
      if (exp == null) return false;
      return exp.toInt() <= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (e) {
      return true; // Token malformado → tratar como expirado.
    }
  }

  Future<AuthUser> login(String correo, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.post('/api/auth/login', {
        'correo': correo.trim(),
        'password': password.trim(),
      });

      final user = AuthUser.fromJson(response);
      _currentUser = user;
      await _api.setToken(user.token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    await _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('auth_token');
    notifyListeners();
  }
}
