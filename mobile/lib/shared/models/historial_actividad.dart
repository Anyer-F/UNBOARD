import 'json_utils.dart';

/// Registro del historial de cambios: quién hizo qué y cuándo.
class HistorialActividad {
  final int id;

  /// ACTIVIDAD, ASIGNACION, ENTREGA, DOCUMENTO, CARTA, EXPEDIENTE,
  /// OBSERVACION, EXPORTACION, SOLICITUD, MODULO o COMUNIDAD.
  final String entidad;
  final String? referencia;
  final int? actividadId;
  final String? actividadTitulo;
  final int? asignacionId;
  final int? apadrinadoId;
  final String? apadrinadoNombre;
  final String? estadoAnterior;
  final String? estadoNuevo;
  final String accion;
  final String? observaciones;
  final int? modificadoPorUsuarioId;
  final String? modificadoPorNombre;
  final String? modificadoPorRol;
  final String? fechaHora;

  HistorialActividad({
    required this.id,
    this.entidad = 'ACTIVIDAD',
    this.referencia,
    this.actividadId,
    this.actividadTitulo,
    this.asignacionId,
    this.apadrinadoId,
    this.apadrinadoNombre,
    this.estadoAnterior,
    this.estadoNuevo,
    required this.accion,
    this.observaciones,
    this.modificadoPorUsuarioId,
    this.modificadoPorNombre,
    this.modificadoPorRol,
    this.fechaHora,
  });

  /// Texto principal: la acción en minúsculas legibles.
  String get accionTexto {
    if (accion.isEmpty) return 'Cambio';
    final s = accion.toLowerCase();
    return s[0].toUpperCase() + s.substring(1);
  }

  factory HistorialActividad.fromJson(Map<String, dynamic> json) {
    return HistorialActividad(
      id: toInt(json['id']),
      entidad: json['entidad'] ?? 'ACTIVIDAD',
      referencia: json['referencia'],
      actividadId: toIntOrNull(json['actividadId']),
      actividadTitulo: json['actividadTitulo'],
      asignacionId: toIntOrNull(json['asignacionId']),
      apadrinadoId: toIntOrNull(json['apadrinadoId']),
      apadrinadoNombre: json['apadrinadoNombre'],
      estadoAnterior: json['estadoAnterior'],
      estadoNuevo: json['estadoNuevo'],
      accion: json['accion'] ?? 'CAMBIO',
      observaciones: json['observaciones'],
      modificadoPorUsuarioId: toIntOrNull(json['modificadoPorUsuarioId']),
      modificadoPorNombre: json['modificadoPorNombre'],
      modificadoPorRol: json['modificadoPorRol'],
      fechaHora: json['fechaHora']?.toString(),
    );
  }
}
