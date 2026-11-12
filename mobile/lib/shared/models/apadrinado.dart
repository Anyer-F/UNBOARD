class Apadrinado {
  final int id;
  final int? usuarioId;
  final String? nombre;
  final String? correo;
  final String? apellido;
  final String? telefono;
  final String? direccion;
  final String? fechaNacimiento;
  final int? coordinadorId;
  final String? coordinadorNombre;
  final int? comunidadId;
  final String? comunidadNombre;

  Apadrinado({
    required this.id,
    this.usuarioId,
    this.nombre,
    this.correo,
    this.apellido,
    this.telefono,
    this.direccion,
    this.fechaNacimiento,
    this.coordinadorId,
    this.coordinadorNombre,
    this.comunidadId,
    this.comunidadNombre,
  });

  /// Nombre y apellido.
  String get nombreCompleto =>
      [nombre, apellido].where((s) => s != null && s.isNotEmpty).join(' ');

  factory Apadrinado.fromJson(Map<String, dynamic> json) {
    return Apadrinado(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      usuarioId: json['usuarioId'] != null ? int.tryParse(json['usuarioId'].toString()) : null,
      nombre: json['nombre'],
      correo: json['correo'],
      apellido: json['apellido'],
      telefono: json['telefono'],
      direccion: json['direccion'],
      fechaNacimiento: json['fechaNacimiento']?.toString(),
      coordinadorId: json['coordinadorId'] != null ? int.tryParse(json['coordinadorId'].toString()) : null,
      coordinadorNombre: json['coordinadorNombre'],
      comunidadId: json['comunidadId'] != null ? int.tryParse(json['comunidadId'].toString()) : null,
      comunidadNombre: json['comunidadNombre'],
    );
  }
}
