import '../core/network/api_client.dart';
import '../shared/models/asignacion.dart';
import '../shared/models/carta.dart';
import '../shared/models/documento.dart';
import '../shared/models/historial_actividad.dart';
import '../shared/models/modulo.dart';

/// Actividades asignadas a cada apadrinado: entrega (apadrinado) y
/// revisión (coordinador).
class AsignacionService {
  final ApiService _api = ApiService();

  // ==================== APADRINADO ====================

  Future<List<Asignacion>> mias() async {
    final response = await _api.get('/api/asignaciones/mias');
    if (response is! List) return [];
    return response.whereType<Map>().map((e) => Asignacion.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Tablero de pendientes ordenado por fecha límite.
  Future<TableroApadrinado> tablero() async {
    return TableroApadrinado.fromJson(await _api.get('/api/asignaciones/tablero'));
  }

  Future<AsignacionDetalle> detalle(int asignacionId) async {
    return AsignacionDetalle.fromJson(await _api.get('/api/asignaciones/$asignacionId'));
  }

  /// Anuncio o material abierto: Publicado → Visto.
  Future<Asignacion> marcarVisto(int asignacionId) async {
    return Asignacion.fromJson(await _api.post('/api/asignaciones/$asignacionId/visto', {}));
  }

  /// Comienza o retoma la entrega (crea el borrador; pasa a En progreso).
  Future<Entrega> iniciarEntrega(int asignacionId) async {
    return Entrega.fromJson(await _api.post('/api/asignaciones/$asignacionId/entrega', {}));
  }

  /// [tipo]: DOCUMENTO, FOTOGRAFIA o EVIDENCIA (si se omite se deduce).
  Future<Documento> subirArchivo(int asignacionId, List<int> bytes, String nombre,
      {String? tipo, String? descripcion}) async {
    final response = await _api.uploadMultipart(
      endpoint: '/api/asignaciones/$asignacionId/entrega/archivos',
      fileBytes: bytes,
      filename: nombre,
      fields: {
        if (tipo != null) 'tipo': tipo,
        if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
      },
    );
    return Documento.fromJson(response);
  }

  Future<void> quitarArchivo(int asignacionId, int documentoId) async {
    await _api.delete('/api/asignaciones/$asignacionId/entrega/archivos/$documentoId');
  }

  Future<Carta> escribirCarta(int asignacionId, {String? titulo, required String contenido, String? tipoCarta}) async {
    return Carta.fromJson(await _api.post('/api/asignaciones/$asignacionId/entrega/cartas', {
      'titulo': titulo,
      'contenido': contenido,
      'tipoCarta': tipoCarta,
    }));
  }

  Future<Carta> editarCarta(int asignacionId, int cartaId,
      {String? titulo, required String contenido, String? tipoCarta}) async {
    return Carta.fromJson(await _api.put('/api/asignaciones/$asignacionId/entrega/cartas/$cartaId', {
      'titulo': titulo,
      'contenido': contenido,
      'tipoCarta': tipoCarta,
    }));
  }

  Future<void> quitarCarta(int asignacionId, int cartaId) async {
    await _api.delete('/api/asignaciones/$asignacionId/entrega/cartas/$cartaId');
  }

  /// Envía la entrega para revisión con el comentario del apadrinado.
  Future<Entrega> enviar(int asignacionId, {String? comentario}) async {
    return Entrega.fromJson(
        await _api.post('/api/asignaciones/$asignacionId/entrega/enviar', {'texto': comentario}));
  }

  // ==================== COORDINADOR ====================

  Future<Entrega> iniciarRevision(int asignacionId) async {
    return Entrega.fromJson(await _api.post('/api/asignaciones/$asignacionId/revision/iniciar', {}));
  }

  /// Aprueba la entrega; [observacion] opcional queda en el expediente.
  Future<Entrega> aprobar(int asignacionId, {String? observacion}) async {
    return Entrega.fromJson(
        await _api.post('/api/asignaciones/$asignacionId/revision/aprobar', {'texto': observacion}));
  }

  /// Solicita una corrección; las [sugerencias] son obligatorias.
  Future<Entrega> solicitarCorreccion(int asignacionId, String sugerencias) async {
    return Entrega.fromJson(
        await _api.post('/api/asignaciones/$asignacionId/revision/correccion', {'texto': sugerencias}));
  }

  Future<List<HistorialActividad>> historial(int asignacionId) async {
    final response = await _api.get('/api/asignaciones/$asignacionId/historial');
    if (response is! List) return [];
    return response.whereType<Map>().map((e) => HistorialActividad.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
