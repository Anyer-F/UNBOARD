import 'json_utils.dart';

/// Solicitud de incorporación a una comunidad, con el perfil del solicitante.
class SolicitudIncorporacion {
  final int id;
  final int? usuarioId;
  final int? comunidadId;
  final String nombre;
  final String? apellido;
  final String? correo;
  final String? telefono;
  final String? direccion;
  final String? fechaNacimiento;
  final String? comunidadNombre;
  final String? codigo;
  final String? fechaSolicitud;
  final String? fechaRespuesta;
  final String? observaciones;

  /// PENDIENTE, APROBADA o RECHAZADA.
  final String estado;

  SolicitudIncorporacion({
    required this.id,
    this.usuarioId,
    this.comunidadId,
    required this.nombre,
    this.apellido,
    this.correo,
    this.telefono,
    this.direccion,
    this.fechaNacimiento,
    this.comunidadNombre,
    this.codigo,
    this.fechaSolicitud,
    this.fechaRespuesta,
    this.observaciones,
    required this.estado,
  });

  String get nombreCompleto =>
      [nombre, apellido].where((s) => s != null && s.isNotEmpty).join(' ');

  bool get pendiente => estado == 'PENDIENTE';
  bool get aprobada => estado == 'APROBADA';
  bool get rechazada => estado == 'RECHAZADA';

  factory SolicitudIncorporacion.fromJson(Map<String, dynamic> json) {
    return SolicitudIncorporacion(
      id: toInt(json['id']),
      usuarioId: toIntOrNull(json['usuarioId']),
      comunidadId: toIntOrNull(json['comunidadId']),
      nombre: json['usuarioNombre'] ?? json['nombre'] ?? 'Solicitante',
      apellido: json['usuarioApellido'],
      correo: json['usuarioCorreo'] ?? json['correo'],
      telefono: json['usuarioTelefono'] ?? json['telefono'],
      direccion: json['usuarioDireccion'],
      fechaNacimiento: json['usuarioFechaNacimiento']?.toString(),
      comunidadNombre: json['comunidadNombre'],
      codigo: json['codigo'],
      fechaSolicitud: json['fechaSolicitud']?.toString(),
      fechaRespuesta: json['fechaRespuesta']?.toString(),
      observaciones: json['observaciones'],
      estado: json['estado'] ?? 'PENDIENTE',
    );
  }
}
