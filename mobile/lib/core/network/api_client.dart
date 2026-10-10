import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente HTTP centralizado para la API REST (Spring Boot).
///
/// - La URL base es configurable y se persiste localmente.
/// - Adjunta el token JWT en cada petición autenticada.
/// - Los widgets nunca contienen URLs ni lógica HTTP.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _defaultEmulatorUrl = 'http://10.0.2.2:8081';
  static const String _defaultLocalhostUrl = 'http://localhost:8081';

  String _baseUrl = '';
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final savedUrl = prefs.getString('api_base_url');

    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    } else {
      // Detección automática según la plataforma
      if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _baseUrl = _defaultLocalhostUrl;
      } else {
        // En emuladores de Android 10.0.2.2 apunta a la máquina host
        _baseUrl = _defaultEmulatorUrl;
      }
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().endsWith('/')
        ? url.trim().substring(0, url.trim().length - 1)
        : url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _baseUrl);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  Map<String, String> _getHeaders({bool isJson = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ==================== MÉTODOS HTTP ====================

  /// Tiempo máximo de espera para cada petición.
  static const Duration _timeout = Duration(seconds: 30);

  /// Ejecuta una petición con timeout y traduce los errores de red
  /// a mensajes claros (evita pantallas cargando indefinidamente).
  Future<dynamic> _enviar(
    Future<http.Response> Function() peticion,
  ) async {
    try {
      final response = await peticion().timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException catch (_) {
      throw Exception(
        'El servidor no respondió a tiempo. '
        'Verifica tu conexión e inténtalo de nuevo.',
      );
    } on SocketException catch (_) {
      throw Exception(
        'Sin conexión con el servidor. '
        'Verifica que el backend esté activo.',
      );
    }
  }

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _enviar(() => http.get(uri, headers: _getHeaders()));
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _enviar(() =>
        http.post(uri, headers: _getHeaders(), body: jsonEncode(body)));
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _enviar(() =>
        http.put(uri, headers: _getHeaders(), body: jsonEncode(body)));
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _enviar(() =>
        http.patch(uri, headers: _getHeaders(), body: jsonEncode(body)));
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _enviar(() => http.delete(uri, headers: _getHeaders()));
  }

  /// Descarga de bytes para archivos (PDF, ZIP, imágenes).
  Future<Uint8List> getBytes(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    // Accept genérico: el backend responde application/pdf o application/zip
    // y rechaza con 406 una petición que solo acepte JSON.
    final headers = _getHeaders(isJson: false)..['Accept'] = '*/*';
    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 90));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      // Reutiliza el mensaje de error del backend cuando lo hay
      _handleResponse(response);
      throw Exception(
        'Error al descargar archivo: código HTTP ${response.statusCode}',
      );
    } on TimeoutException catch (_) {
      throw Exception(
        'El servidor no respondió a tiempo al descargar el archivo.',
      );
    } on SocketException catch (_) {
      throw Exception('Sin conexión al descargar el archivo.');
    }
  }

  /// Subida de archivos con multipart.
  Future<dynamic> uploadMultipart({
    required String endpoint,
    required List<int> fileBytes,
    required String filename,
    required Map<String, String> fields,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);

    if (_token != null && _token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.fields.addAll(fields);

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on TimeoutException catch (_) {
      throw Exception(
        'El servidor no respondió a tiempo al subir el archivo.',
      );
    } on SocketException catch (_) {
      throw Exception('Sin conexión al subir el archivo.');
    }
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        return response.body;
      }
    } else {
      String errorMessage = 'Error en el servidor ($statusCode)';
      try {
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorJson is Map && errorJson.containsKey('message')) {
          errorMessage = errorJson['message'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }
}
