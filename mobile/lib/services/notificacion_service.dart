import '../shared/models/notificacion.dart';
import '../core/network/api_client.dart';

class NotificacionService {
  final ApiService _api = ApiService();

  Future<List<Notificacion>> listarPorUsuario(int usuarioId, {bool? soloNoLeidas}) async {
    String endpoint = '/api/notificaciones/usuario/$usuarioId';
    if (soloNoLeidas != null) {
      endpoint += '?soloNoLeidas=$soloNoLeidas';
    }
    final response = await _api.get(endpoint);
    if (response is List) {
      return response.map((n) => Notificacion.fromJson(n)).toList();
    }
    return [];
  }

  Future<int> contarNoLeidas(int usuarioId) async {
    try {
      final response = await _api.get('/api/notificaciones/usuario/$usuarioId/conteo-no-leidas');
      if (response is Map && response.containsKey('noLeidas')) {
        return int.tryParse(response['noLeidas'].toString()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> marcarComoLeida(int id) async {
    await _api.patch('/api/notificaciones/$id/leer', {});
  }

  Future<void> marcarTodasComoLeidas(int usuarioId) async {
    await _api.patch('/api/notificaciones/usuario/$usuarioId/leer-todas', {});
  }
}
