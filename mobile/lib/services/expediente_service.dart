import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../core/utils/file_export.dart';
import '../shared/models/apadrinado.dart';
import '../shared/models/documento.dart';
import '../shared/models/expediente.dart';
import '../shared/models/historial_actividad.dart';

/// Expedientes digitales, gestión documental y exportaciones
/// (funciones exclusivas del coordinador).
class ExpedienteService {
  final ApiService _api = ApiService();

  /// Apadrinados de las comunidades del coordinador.
  Future<List<Apadrinado>> apadrinados() async =>
      _lista(await _api.get('/api/apadrinados'), Apadrinado.fromJson);

  Future<Expediente> obtenerPorApadrinado(int apadrinadoId) async =>
      Expediente.fromJson(await _api.get('/api/expedientes/apadrinado/$apadrinadoId'));

  Future<Observacion> agregarObservacion(int apadrinadoId, String texto, {int? asignacionId}) async {
    return Observacion.fromJson(await _api.post('/api/expedientes/apadrinado/$apadrinadoId/observaciones', {
      'texto': texto,
      'asignacionId': asignacionId,
    }));
  }

  Future<void> eliminarObservacion(int observacionId) async =>
      _api.delete('/api/expedientes/observaciones/$observacionId');

  Future<List<HistorialActividad>> historial(int apadrinadoId) async =>
      _lista(await _api.get('/api/expedientes/apadrinado/$apadrinadoId/historial'), HistorialActividad.fromJson);

  /// Historial de todas las comunidades del coordinador.
  Future<List<HistorialActividad>> historialGeneral() async =>
      _lista(await _api.get('/api/historial'), HistorialActividad.fromJson);

  /// Documentos del apadrinado clasificados por tipo, actividad y estado.
  Future<List<Documento>> documentos(int apadrinadoId, {String? tipo, int? actividadId, String? estado}) async {
    final params = <String>[
      if (tipo != null) 'tipo=$tipo',
      if (actividadId != null) 'actividadId=$actividadId',
      if (estado != null) 'estado=$estado',
    ];
    return _lista(
        await _api.get('/api/documentos/apadrinado/$apadrinadoId${params.isEmpty ? '' : '?${params.join('&')}'}'),
        Documento.fromJson);
  }

  // ==================== EXPORTACIONES ====================

  /// Expediente PDF del apadrinado por intervalo (fecha de asignación).
  Future<Exportacion> exportarPdf(int apadrinadoId, {DateTime? desde, DateTime? hasta}) async =>
      Exportacion.fromJson(
          await _api.post('/api/expedientes/apadrinado/$apadrinadoId/exportar-pdf${_periodo(desde, hasta)}', {}));

  /// ZIP con los archivos de las entregas aprobadas en el intervalo.
  Future<Exportacion> exportarZip(int apadrinadoId, {DateTime? desde, DateTime? hasta}) async =>
      Exportacion.fromJson(
          await _api.post('/api/expedientes/apadrinado/$apadrinadoId/exportar-zip${_periodo(desde, hasta)}', {}));

  Future<List<Exportacion>> misExportaciones() async =>
      _lista(await _api.get('/api/exportaciones'), Exportacion.fromJson);

  Future<Uint8List> descargarBytes(Exportacion e) => _api.getBytes(e.urlDescarga);

  /// Descarga el archivo generado y lo guarda / abre en el dispositivo.
  Future<String> descargarYAbrir(Exportacion e) async {
    final bytes = await descargarBytes(e);
    return guardarYAbrirArchivo(bytes,
        nombre: e.nombreArchivo, mimeType: e.tipoMime ?? (e.esPdf ? 'application/pdf' : 'application/zip'));
  }

  static String _periodo(DateTime? desde, DateTime? hasta) {
    String f(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final params = <String>[
      if (desde != null) 'desde=${f(desde)}',
      if (hasta != null) 'hasta=${f(hasta)}',
    ];
    return params.isEmpty ? '' : '?${params.join('&')}';
  }

  static List<T> _lista<T>(dynamic response, T Function(Map<String, dynamic>) fromJson) {
    if (response is! List) return <T>[];
    return response.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
