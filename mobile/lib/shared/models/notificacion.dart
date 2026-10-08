class Notificacion {
  final int id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final String? fechaCreacion;
  final bool leida;
  final int? idReferencia;
  final String? tipoReferencia;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    this.fechaCreacion,
    this.leida = false,
    this.idReferencia,
    this.tipoReferencia,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      titulo: json['titulo'] ?? '',
      mensaje: json['mensaje'] ?? '',
      tipo: json['tipo'] ?? 'GENERAL',
      fechaCreacion: json['fechaCreacion'],
      leida: json['leida'] == true,
      idReferencia: json['idReferencia'] != null ? int.tryParse(json['idReferencia'].toString()) : null,
      tipoReferencia: json['tipoReferencia'],
    );
  }
}
