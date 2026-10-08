/// Solicitud de incorporación a una comunidad (especificación §24).
class SolicitudIncorporacion {
  final int id;
  final int? comunidadId;
  final String nombre;
  final String? correo;
  final String? telefono;
  final String? comunidadNombre;
  final String? fechaSolicitud;
  final String? informacionBasica;
  final String estado;

  SolicitudIncorporacion({
    required this.id,
    this.comunidadId,
    required this.nombre,
    this.correo,
    this.telefono,
    this.comunidadNombre,
    this.fechaSolicitud,
    this.informacionBasica,
    this.estado = 'PENDIENTE',
  });

  bool get isPendiente => estado.toUpperCase() == 'PENDIENTE';

  factory SolicitudIncorporacion.fromJson(Map<String, dynamic> json) {
    return SolicitudIncorporacion(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      comunidadId: json['comunidadId'] != null
          ? int.tryParse(json['comunidadId'].toString())
          : null,
      nombre: json['nombre'] ??
          json['usuarioNombre'] ??
          json['nombreCompleto'] ??
          '',
      correo: json['correo'] ?? json['usuarioCorreo'],
      telefono: json['telefono'],
      comunidadNombre: json['comunidadNombre'] ?? json['comunidad'],
      fechaSolicitud: json['fechaSolicitud'] ?? json['fechaCreacion'],
      informacionBasica: json['informacionBasica'] ?? json['notas'],
      estado: json['estado'] ?? 'PENDIENTE',
    );
  }
}
