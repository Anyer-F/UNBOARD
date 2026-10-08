import 'dart:typed_data';
import '../shared/models/apadrinado.dart';
import '../shared/models/comunidad.dart';
import '../shared/models/expediente.dart';
import '../shared/models/solicitud_incorporacion.dart';
import '../core/network/api_client.dart';

class ExpedienteService {
  final ApiService _api = ApiService();

  Future<Expediente> obtenerPorId(int id) async {
    final response = await _api.get('/api/expedientes/$id');
    return Expediente.fromJson(response);
  }

  Future<Expediente> obtenerPorApadrinadoId(int apadrinadoId) async {
    final response = await _api.get('/api/expedientes/apadrinado/$apadrinadoId');
    return Expediente.fromJson(response);
  }

  Future<Uint8List> descargarPdf(int expedienteId) async {
    return await _api.getBytes('/api/expedientes/$expedienteId/exportar-pdf');
  }

  Future<Uint8List> descargarZip(int expedienteId) async {
    return await _api.getBytes('/api/expedientes/$expedienteId/exportar-zip');
  }

  Future<List<Apadrinado>> listarApadrinadosPorCoordinador(int coordinadorId) async {
    final response = await _api.get('/api/apadrinados/coordinador/$coordinadorId');
    if (response is List) {
      return response.map((a) => Apadrinado.fromJson(a)).toList();
    }
    return [];
  }

  Future<List<Apadrinado>> listarTodosLosApadrinados() async {
    final response = await _api.get('/api/apadrinados');
    if (response is List) {
      return response.map((a) => Apadrinado.fromJson(a)).toList();
    }
    return [];
  }

  Future<Apadrinado> crearApadrinado(Map<String, dynamic> data) async {
    final response = await _api.post('/api/apadrinados', data);
    return Apadrinado.fromJson(response);
  }

  Future<List<Comunidad>> listarComunidades() async {
    final response = await _api.get('/api/comunidades');
    if (response is List) {
      return response.map((c) => Comunidad.fromJson(c)).toList();
    }
    return [];
  }

  /// Une un apadrinado a una comunidad mediante código (§21.4).
  Future<void> unirComunidad({
    required int apadrinadoId,
    required String codigo,
  }) async {
    await _api.post('/api/comunidades/unirse', {
      'apadrinadoId': apadrinadoId,
      'codigo': codigo,
    });
  }

  /// Obtiene el código de acceso activo de una comunidad (§23).
  Future<String> obtenerCodigoComunidad(int comunidadId) async {
    final response =
        await _api.get('/api/codigos-acceso/comunidad/$comunidadId');
    if (response is List) {
      for (final c in response) {
        if (c is Map && c['activo'] == true && c['codigo'] != null) {
          return c['codigo'].toString();
        }
      }
      if (response.isNotEmpty &&
          response.first is Map &&
          response.first['codigo'] != null) {
        return response.first['codigo'].toString();
      }
    }
    return '';
  }

  /// Lista las solicitudes pendientes de una comunidad (§24).
  Future<List<SolicitudIncorporacion>> listarSolicitudes(
      int comunidadId) async {
    final response =
        await _api.get('/api/solicitudes-incorporacion/pendientes');
    if (response is List) {
      return response
          .where((s) =>
              s is Map &&
              s['comunidadId'] != null &&
              int.tryParse(s['comunidadId'].toString()) == comunidadId)
          .map((s) => SolicitudIncorporacion.fromJson(s))
          .toList();
    }
    return [];
  }

  /// Acepta o rechaza una solicitud de incorporación (§24).
  Future<void> responderSolicitud(
    int solicitudId, {
    required bool aceptar,
    String? observaciones,
  }) async {
    if (aceptar) {
      await _api.patch(
          '/api/solicitudes-incorporacion/$solicitudId/aprobar', {});
    } else {
      await _api.patch(
        '/api/solicitudes-incorporacion/$solicitudId/rechazar',
        {'observaciones': observaciones},
      );
    }
  }

  /// Lista las comunidades bajo responsabilidad del coordinador
  /// autenticado (principal + asociadas).
  Future<List<Comunidad>> listarMisComunidades() async {
    final response = await _api.get('/api/coordinadores/comunidades');
    if (response is List) {
      return response.map((c) => Comunidad.fromJson(c)).toList();
    }
    return [];
  }
}
