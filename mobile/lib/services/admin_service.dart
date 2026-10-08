import '../core/network/api_client.dart';

class AdminService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> obtenerEstadisticasGlobales() async {
    final response = await _api.get('/api/admin/estadisticas');
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
  }

  Future<List<dynamic>> listarUsuarios() async {
    final response = await _api.get('/api/admin/usuarios');
    if (response is List) {
      return response;
    }
    return [];
  }

  Future<dynamic> crearUsuario({
    required String nombre,
    required String correo,
    required String password,
    required String rol,
  }) async {
    return await _api.post('/api/admin/usuarios', {
      'nombre': nombre,
      'correo': correo,
      'password': password,
      'rol': rol,
    });
  }

  Future<dynamic> actualizarUsuario({
    required int usuarioId,
    required String nombre,
    required String correo,
    required String rol,
  }) async {
    return await _api.put('/api/admin/usuarios/$usuarioId', {
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
    });
  }

  Future<void> eliminarUsuario(int usuarioId) async {
    await _api.delete('/api/admin/usuarios/$usuarioId');
  }

  Future<List<dynamic>> listarComunidades() async {
    final response = await _api.get('/api/comunidades');
    if (response is List) {
      return response;
    }
    return [];
  }

  Future<dynamic> crearComunidad({
    required String nombre,
    required String municipio,
    required String departamento,
  }) async {
    return await _api.post('/api/comunidades', {
      'nombre': nombre,
      'municipio': municipio,
      'departamento': departamento,
    });
  }

  Future<dynamic> actualizarComunidad({
    required int comunidadId,
    required String nombre,
    required String municipio,
    required String departamento,
  }) async {
    return await _api.put('/api/comunidades/$comunidadId', {
      'nombre': nombre,
      'municipio': municipio,
      'departamento': departamento,
    });
  }

  Future<void> eliminarComunidad(int comunidadId) async {
    await _api.delete('/api/comunidades/$comunidadId');
  }
}
