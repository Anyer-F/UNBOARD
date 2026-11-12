import '../core/network/api_client.dart';
import '../shared/models/actividad.dart';
import '../shared/models/asignacion.dart';
import '../shared/models/documento.dart';
import '../shared/models/expediente.dart';
import '../shared/models/historial_actividad.dart';

/// Actividades (funciones del coordinador): tablero, CRUD, contenido
/// adjunto, cambio de módulo, historial y exportación.
class ActividadService {
  final ApiService _api = ApiService();

  /// Tablero de actividades, filtrable por comunidad, módulo y tipo.
  Future<List<Actividad>> tablero({int? comunidadId, int? moduloId, String? tipo}) async {
    final params = <String>[
      if (comunidadId != null) 'comunidadId=$comunidadId',
      if (moduloId != null) 'moduloId=$moduloId',
      if (tipo != null) 'tipo=$tipo',
    ];
    final response = await _api.get('/api/actividades${params.isEmpty ? '' : '?${params.join('&')}'}');
    return _lista(response, Actividad.fromJson);
  }

  Future<ActividadDetalle> detalle(int actividadId) async {
    return ActividadDetalle.fromJson(await _api.get('/api/actividades/$actividadId'));
  }

  /// [datos]: tipo, titulo, descripcion, instrucciones, fechaLimite
  /// (yyyy-MM-dd), requiereDocumento, requiereFotografia, requiereCarta,
  /// otrosRequisitos, comunidadId, moduloId, asignarAComunidad, apadrinadoIds.
  Future<Actividad> crear(Map<String, dynamic> datos) async {
    return Actividad.fromJson(await _api.post('/api/actividades', datos));
  }

  Future<Actividad> actualizar(int actividadId, Map<String, dynamic> datos) async {
    return Actividad.fromJson(await _api.put('/api/actividades/$actividadId', datos));
  }

  /// Elimina la actividad. Si tiene entregas el backend responde 409
  /// ([ApiException.requiereConfirmacion]) hasta que se envíe [confirmar].
  /// Devuelve 'LOGICA' o 'DEFINITIVA'.
  Future<String> eliminar(int actividadId, {bool confirmar = false}) async {
    final response = await _api.delete('/api/actividades/$actividadId?confirmar=$confirmar');
    return response is Map ? (response['eliminacion']?.toString() ?? '') : '';
  }

  /// Contenido del coordinador: documentos, fotografías o material.
  Future<Documento> subirAdjunto(int actividadId, List<int> bytes, String nombre, {String? descripcion}) async {
    final response = await _api.uploadMultipart(
      endpoint: '/api/actividades/$actividadId/adjuntos',
      fileBytes: bytes,
      filename: nombre,
      fields: {if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion},
    );
    return Documento.fromJson(response);
  }

  Future<void> eliminarAdjunto(int actividadId, int documentoId) async {
    await _api.delete('/api/actividades/$actividadId/adjuntos/$documentoId');
  }

  Future<ActividadDetalle> moverAModulo(int actividadId, int moduloId) async {
    return ActividadDetalle.fromJson(
        await _api.patch('/api/actividades/$actividadId/modulo', {'moduloId': moduloId}));
  }

  Future<List<HistorialActividad>> historial(int actividadId) async {
    return _lista(await _api.get('/api/actividades/$actividadId/historial'), HistorialActividad.fromJson);
  }

  /// Expediente PDF de la actividad con las entregas aprobadas.
  Future<Exportacion> exportarPdf(int actividadId) async {
    return Exportacion.fromJson(await _api.post('/api/actividades/$actividadId/exportar-pdf', {}));
  }

  /// Carpeta ZIP con los archivos de las entregas aprobadas.
  Future<Exportacion> exportarZip(int actividadId) async {
    return Exportacion.fromJson(await _api.post('/api/actividades/$actividadId/exportar-zip', {}));
  }

  static List<T> _lista<T>(dynamic response, T Function(Map<String, dynamic>) fromJson) {
    if (response is! List) return <T>[];
    return response.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
