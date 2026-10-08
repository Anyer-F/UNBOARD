class HistorialActividad {
  final int id;
  final int actividadId;
  final String? actividadTitulo;
  final String? estadoAnterior;
  final String estadoNuevo;
  final String accion;
  final String? observaciones;
  final int? modificadoPorUsuarioId;
  final String? modificadoPorNombre;
  final String? modificadoPorRol;
  final String? fechaHora;

  HistorialActividad({
    required this.id,
    required this.actividadId,
    this.actividadTitulo,
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.accion,
    this.observaciones,
    this.modificadoPorUsuarioId,
    this.modificadoPorNombre,
    this.modificadoPorRol,
    this.fechaHora,
  });

  factory HistorialActividad.fromJson(Map<String, dynamic> json) {
    return HistorialActividad(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      actividadId: json['actividadId'] is int
          ? json['actividadId']
          : int.parse(json['actividadId'].toString()),
      actividadTitulo: json['actividadTitulo'],
      estadoAnterior: json['estadoAnterior'],
      estadoNuevo: json['estadoNuevo'] ?? 'PENDIENTE',
      accion: json['accion'] ?? 'CAMBIO',
      observaciones: json['observaciones'],
      modificadoPorUsuarioId: json['modificadoPorUsuarioId'],
      modificadoPorNombre: json['modificadoPorNombre'],
      modificadoPorRol: json['modificadoPorRol'],
      fechaHora: json['fechaHora'],
    );
  }
}
