import '../shared/models/actividad.dart';
import '../shared/models/historial_actividad.dart';
import '../core/network/api_client.dart';

class ActividadService {
  final ApiService _api = ApiService();

  Future<List<Actividad>> listarPorApadrinado(int apadrinadoId, {String? estado}) async {
    String endpoint = '/api/actividades/apadrinado/$apadrinadoId';
    if (estado != null && estado.isNotEmpty) {
      endpoint += '?estado=$estado';
    }
    final response = await _api.get(endpoint);
    if (response is List) {
      return response.map((a) => Actividad.fromJson(a)).toList();
    }
    return [];
  }

  Future<List<Actividad>> listarPorCoordinador(int coordinadorId, {String? estado}) async {
    String endpoint = '/api/actividades/coordinador/$coordinadorId';
    if (estado != null && estado.isNotEmpty) {
      endpoint += '?estado=$estado';
    }
    final response = await _api.get(endpoint);
    if (response is List) {
      return response.map((a) => Actividad.fromJson(a)).toList();
    }
    return [];
  }

  Future<Actividad> obtenerPorId(int id) async {
    final response = await _api.get('/api/actividades/$id');
    return Actividad.fromJson(response);
  }

  Future<Actividad> crear(Map<String, dynamic> data) async {
    final response = await _api.post('/api/actividades', data);
    return Actividad.fromJson(response);
  }

  Future<List<Actividad>> crearMasiva(Map<String, dynamic> data) async {
    final response = await _api.post('/api/actividades/masiva', data);
    if (response is List) {
      return response.map((a) => Actividad.fromJson(a)).toList();
    }
    return [];
  }

  Future<Actividad> actualizar(int id, Map<String, dynamic> data) async {
    final response = await _api.put('/api/actividades/$id', data);
    return Actividad.fromJson(response);
  }

  Future<void> eliminar(int id) async {
    await _api.delete('/api/actividades/$id');
  }

  Future<Actividad> cambiarEstado(int id, String estado, {String? observaciones}) async {
    final response = await _api.patch('/api/actividades/$id/estado', {
      'estado': estado,
      'observaciones': observaciones,
    });
    return Actividad.fromJson(response);
  }

  Future<List<HistorialActividad>> obtenerHistorialPorActividad(int actividadId) async {
    final response = await _api.get('/api/actividades/$actividadId/historial');
    if (response is List) {
      return response.map((h) => HistorialActividad.fromJson(h)).toList();
    }
    return [];
  }

  Future<List<HistorialActividad>> obtenerHistorialPorApadrinado(int apadrinadoId) async {
    final response = await _api.get('/api/actividades/apadrinado/$apadrinadoId/historial');
    if (response is List) {
      return response.map((h) => HistorialActividad.fromJson(h)).toList();
    }
    return [];
  }
}
