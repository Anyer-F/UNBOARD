import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/auth_user.dart';

/// Almacenamiento local de la sesión del usuario (token JWT + perfil).
///
/// No se almacenan contraseñas en texto plano, únicamente el token
/// y el perfil del usuario para restaurar la sesión.
class SessionStorage {
  static const _keyToken = 'auth_token';
  static const _keyUser = 'current_user';
  static const _keyApiUrl = 'api_base_url';

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> saveSession(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, user.token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<AuthUser?> get user async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(userJson));
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  Future<String?> get apiBaseUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiUrl);
  }

  Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiUrl, url);
  }
}
