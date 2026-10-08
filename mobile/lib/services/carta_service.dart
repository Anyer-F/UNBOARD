import '../shared/models/carta.dart';
import '../core/network/api_client.dart';

class CartaService {
  final ApiService _api = ApiService();

  Future<List<Carta>> listarTodas() async {
    final response = await _api.get('/api/cartas');
    if (response is List) {
      return response.map((c) => Carta.fromJson(c)).toList();
    }
    return [];
  }

  Future<Carta> obtenerPorId(int id) async {
    final response = await _api.get('/api/cartas/$id');
    return Carta.fromJson(response);
  }

  Future<List<Carta>> listarPorApadrinado(int apadrinadoId) async {
    final response = await _api.get('/api/cartas/apadrinado/$apadrinadoId');
    if (response is List) {
      return response.map((c) => Carta.fromJson(c)).toList();
    }
    return [];
  }

  Future<List<Carta>> listarPorExpediente(int expedienteId) async {
    final response = await _api.get('/api/cartas/expediente/$expedienteId');
    if (response is List) {
      return response.map((c) => Carta.fromJson(c)).toList();
    }
    return [];
  }

  Future<List<Carta>> listarPorActividad(int actividadId) async {
    final response = await _api.get('/api/cartas/actividad/$actividadId');
    if (response is List) {
      return response.map((c) => Carta.fromJson(c)).toList();
    }
    return [];
  }

  Future<List<Carta>> listarPorEstado(String estado) async {
    final response = await _api.get('/api/cartas/estado/$estado');
    if (response is List) {
      return response.map((c) => Carta.fromJson(c)).toList();
    }
    return [];
  }

  Future<Carta> crear({
    required String titulo,
    required String contenido,
    required int apadrinadoId,
    int? actividadId,
    String? tipoCarta,
    String? observaciones,
  }) async {
    final body = {
      'titulo': titulo,
      'contenido': contenido,
      'apadrinadoId': apadrinadoId,
      if (actividadId != null) 'actividadId': actividadId,
      if (tipoCarta != null) 'tipoCarta': tipoCarta,
      if (observaciones != null) 'observaciones': observaciones,
    };

    final response = await _api.post('/api/cartas', body);
    return Carta.fromJson(response);
  }

  Future<Carta> actualizar({
    required int id,
    String? titulo,
    String? contenido,
    String? tipoCarta,
    String? observaciones,
  }) async {
    final body = <String, dynamic>{};
    if (titulo != null) body['titulo'] = titulo;
    if (contenido != null) body['contenido'] = contenido;
    if (tipoCarta != null) body['tipoCarta'] = tipoCarta;
    if (observaciones != null) body['observaciones'] = observaciones;

    final response = await _api.put('/api/cartas/$id', body);
    return Carta.fromJson(response);
  }

  Future<Carta> enviarCarta(int id) async {
    final response = await _api.patch('/api/cartas/$id/enviar', {});
    return Carta.fromJson(response);
  }

  Future<Carta> cambiarEstado(int id, String estado) async {
    final response = await _api.patch('/api/cartas/$id/estado?estado=$estado', {});
    return Carta.fromJson(response);
  }

  Future<void> eliminar(int id) async {
    await _api.delete('/api/cartas/$id');
  }
}
