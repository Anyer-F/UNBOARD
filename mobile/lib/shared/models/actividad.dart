class Actividad {
  final int id;
  final String titulo;
  final String? descripcion;
  final String? fechaCreacion;
  final String? fechaLimite;
  final bool requiereDocumento;
  final bool requiereFotografia;
  final String estado;
  final String? observaciones;
  final int? coordinadorId;
  final String? coordinadorNombre;
  final int? apadrinadoId;
  final String? apadrinadoNombre;

  Actividad({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.fechaCreacion,
    this.fechaLimite,
    this.requiereDocumento = false,
    this.requiereFotografia = false,
    required this.estado,
    this.observaciones,
    this.coordinadorId,
    this.coordinadorNombre,
    this.apadrinadoId,
    this.apadrinadoNombre,
  });

  factory Actividad.fromJson(Map<String, dynamic> json) {
    return Actividad(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'],
      fechaCreacion: json['fechaCreacion'],
      fechaLimite: json['fechaLimite'],
      requiereDocumento: json['requiereDocumento'] == true,
      requiereFotografia: json['requiereFotografia'] == true,
      estado: json['estado'] ?? 'PENDIENTE',
      observaciones: json['observaciones'],
      coordinadorId: json['coordinadorId'] != null ? int.tryParse(json['coordinadorId'].toString()) : null,
      coordinadorNombre: json['coordinadorNombre'],
      apadrinadoId: json['apadrinadoId'] != null ? int.tryParse(json['apadrinadoId'].toString()) : null,
      apadrinadoNombre: json['apadrinadoNombre'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'fechaCreacion': fechaCreacion,
      'fechaLimite': fechaLimite,
      'requiereDocumento': requiereDocumento,
      'requiereFotografia': requiereFotografia,
      'estado': estado,
      'observaciones': observaciones,
      'coordinadorId': coordinadorId,
      'apadrinadoId': apadrinadoId,
    };
  }
}
