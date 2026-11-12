import '../core/network/api_client.dart';
import '../shared/models/apadrinado.dart';
import '../shared/models/comunidad.dart';
import '../shared/models/historial_actividad.dart';
import '../shared/models/modulo.dart';
import '../shared/models/solicitud_incorporacion.dart';

/// Código de acceso de una comunidad.
class CodigoAcceso {
  final int id;
  final String codigo;
  final bool activo;
  final int? maxUsos;
  final int usos;
  final String? fechaExpiracion;
  final String? descripcion;

  CodigoAcceso({
    required this.id,
    required this.codigo,
    this.activo = true,
    this.maxUsos,
    this.usos = 0,
    this.fechaExpiracion,
    this.descripcion,
  });

  factory CodigoAcceso.fromJson(Map<String, dynamic> json) => CodigoAcceso(
        id: int.tryParse(json['id'].toString()) ?? 0,
        codigo: json['codigo'] ?? '',
        activo: json['activo'] == true,
        maxUsos: json['maxUsos'] != null ? int.tryParse(json['maxUsos'].toString()) : null,
        usos: int.tryParse((json['usos'] ?? 0).toString()) ?? 0,
        fechaExpiracion: json['fechaExpiracion']?.toString(),
        descripcion: json['descripcion'],
      );
}

/// Comunidades, módulos, códigos de acceso y solicitudes de incorporación.
class ComunidadService {
  final ApiService _api = ApiService();

  // ==================== COMUNIDADES ====================

  /// Comunidades del usuario (las que administra o a la que pertenece).
  Future<List<Comunidad>> listar() async => _lista(await _api.get('/api/comunidades'), Comunidad.fromJson);

  Future<Comunidad> obtener(int id) async => Comunidad.fromJson(await _api.get('/api/comunidades/$id'));

  /// Apadrinado: su comunidad, su coordinador y los módulos con sus actividades.
  Future<MiComunidad> miComunidad() async => MiComunidad.fromJson(await _api.get('/api/comunidades/mia'));

  Future<Comunidad> crear({
    required String nombre,
    String? municipio,
    String? departamento,
    String modoIncorporacion = 'SOLICITUD',
  }) async {
    return Comunidad.fromJson(await _api.post('/api/comunidades', {
      'nombre': nombre,
      'municipio': municipio,
      'departamento': departamento,
      'modoIncorporacion': modoIncorporacion,
    }));
  }

  Future<Comunidad> actualizar(int id, Map<String, dynamic> datos) async {
    return Comunidad.fromJson(await _api.put('/api/comunidades/$id', datos));
  }

  Future<void> eliminar(int id) async => _api.delete('/api/comunidades/$id');

  Future<List<Apadrinado>> apadrinados(int comunidadId) async =>
      _lista(await _api.get('/api/apadrinados/comunidad/$comunidadId'), Apadrinado.fromJson);

  Future<List<HistorialActividad>> historial(int comunidadId) async =>
      _lista(await _api.get('/api/comunidades/$comunidadId/historial'), HistorialActividad.fromJson);

  // ==================== MÓDULOS ====================

  Future<List<Modulo>> modulos(int comunidadId) async =>
      _lista(await _api.get('/api/comunidades/$comunidadId/modulos'), Modulo.fromJson);

  Future<Modulo> crearModulo(int comunidadId, {required String nombre, String? descripcion}) async {
    return Modulo.fromJson(
        await _api.post('/api/comunidades/$comunidadId/modulos', {'nombre': nombre, 'descripcion': descripcion}));
  }

  Future<Modulo> actualizarModulo(int moduloId, {String? nombre, String? descripcion, int? orden}) async {
    return Modulo.fromJson(await _api.put('/api/modulos/$moduloId', {
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (orden != null) 'orden': orden,
    }));
  }

  /// Solo módulos sin actividades; la comunidad conserva al menos uno.
  Future<void> eliminarModulo(int moduloId) async => _api.delete('/api/modulos/$moduloId');

  /// Nuevo orden: lista completa de los IDs de los módulos.
  Future<List<Modulo>> reordenarModulos(int comunidadId, List<int> ids) async =>
      _lista(await _api.put('/api/comunidades/$comunidadId/modulos/orden', {'ids': ids}), Modulo.fromJson);

  // ==================== CÓDIGOS DE ACCESO ====================

  Future<List<CodigoAcceso>> codigos(int comunidadId) async =>
      _lista(await _api.get('/api/codigos-acceso/comunidad/$comunidadId'), CodigoAcceso.fromJson);

  Future<CodigoAcceso> generarCodigo(int comunidadId, {int? maxUsos, DateTime? expira, String? descripcion}) async {
    return CodigoAcceso.fromJson(await _api.post('/api/codigos-acceso/comunidad/$comunidadId', {
      'maxUsos': maxUsos,
      'fechaExpiracion': expira?.toIso8601String(),
      'descripcion': descripcion,
    }));
  }

  Future<void> desactivarCodigo(int codigoId) async => _api.delete('/api/codigos-acceso/$codigoId');

  // ==================== SOLICITUDES ====================

  /// Apadrinado: solicita incorporarse con el código (la comunidad se deduce).
  Future<SolicitudIncorporacion> solicitarIncorporacion(String codigo) async {
    return SolicitudIncorporacion.fromJson(
        await _api.post('/api/solicitudes-incorporacion', {'codigo': codigo.trim().toUpperCase()}));
  }

  Future<List<SolicitudIncorporacion>> misSolicitudes() async =>
      _lista(await _api.get('/api/solicitudes-incorporacion/mias'), SolicitudIncorporacion.fromJson);

  Future<List<SolicitudIncorporacion>> solicitudesPendientes({int? comunidadId}) async => _lista(
      await _api.get('/api/solicitudes-incorporacion/pendientes${comunidadId != null ? '?comunidadId=$comunidadId' : ''}'),
      SolicitudIncorporacion.fromJson);

  /// Perfil del solicitante.
  Future<SolicitudIncorporacion> solicitud(int id) async =>
      SolicitudIncorporacion.fromJson(await _api.get('/api/solicitudes-incorporacion/$id'));

  Future<SolicitudIncorporacion> aprobarSolicitud(int id) async =>
      SolicitudIncorporacion.fromJson(await _api.patch('/api/solicitudes-incorporacion/$id/aprobar', {}));

  Future<SolicitudIncorporacion> rechazarSolicitud(int id, {String? motivo}) async {
    final q = motivo != null && motivo.isNotEmpty ? '?observaciones=${Uri.encodeQueryComponent(motivo)}' : '';
    return SolicitudIncorporacion.fromJson(await _api.patch('/api/solicitudes-incorporacion/$id/rechazar$q', {}));
  }

  static List<T> _lista<T>(dynamic response, T Function(Map<String, dynamic>) fromJson) {
    if (response is! List) return <T>[];
    return response.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
