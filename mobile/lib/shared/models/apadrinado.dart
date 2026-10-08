class Apadrinado {
  final int id;
  final int? usuarioId;
  final String? nombre;
  final String? correo;
  final int? coordinadorId;
  final String? coordinadorNombre;
  final int? comunidadId;
  final String? comunidadNombre;

  Apadrinado({
    required this.id,
    this.usuarioId,
    this.nombre,
    this.correo,
    this.coordinadorId,
    this.coordinadorNombre,
    this.comunidadId,
    this.comunidadNombre,
  });

  factory Apadrinado.fromJson(Map<String, dynamic> json) {
    return Apadrinado(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      usuarioId: json['usuarioId'] != null ? int.tryParse(json['usuarioId'].toString()) : null,
      nombre: json['nombre'],
      correo: json['correo'],
      coordinadorId: json['coordinadorId'] != null ? int.tryParse(json['coordinadorId'].toString()) : null,
      coordinadorNombre: json['coordinadorNombre'],
      comunidadId: json['comunidadId'] != null ? int.tryParse(json['comunidadId'].toString()) : null,
      comunidadNombre: json['comunidadNombre'],
    );
  }
}
