class Comunidad {
  final int id;
  final String nombre;
  final String? municipio;
  final String? departamento;

  Comunidad({
    required this.id,
    required this.nombre,
    this.municipio,
    this.departamento,
  });

  factory Comunidad.fromJson(Map<String, dynamic> json) {
    return Comunidad(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      municipio: json['municipio'],
      departamento: json['departamento'],
    );
  }
}
