/// Operación de actividad dentro de una comunidad (creación masiva:
/// mismo título y fecha de creación para varios apadrinados).
class ActividadComunidadResumen {
  /// Actividad de referencia de la operación.
  final int actividadId;
  final String titulo;
  final String? fechaCreacion;
  final String? fechaLimite;
  final int comunidadId;
  final String? comunidadNombre;
  final int totalAsignadas;
  final int totalAprobadas;

  ActividadComunidadResumen({
    required this.actividadId,
    required this.titulo,
    this.fechaCreacion,
    this.fechaLimite,
    required this.comunidadId,
    this.comunidadNombre,
    this.totalAsignadas = 0,
    this.totalAprobadas = 0,
  });

  factory ActividadComunidadResumen.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

    return ActividadComunidadResumen(
      actividadId: toInt(json['actividadId']),
      titulo: json['titulo'] ?? '',
      fechaCreacion: json['fechaCreacion'],
      fechaLimite: json['fechaLimite'],
      comunidadId: toInt(json['comunidadId']),
      comunidadNombre: json['comunidadNombre'],
      totalAsignadas: toInt(json['totalAsignadas']),
      totalAprobadas: toInt(json['totalAprobadas']),
    );
  }
}
