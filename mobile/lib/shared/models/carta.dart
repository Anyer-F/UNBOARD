class Carta {
  final int id;
  final String titulo;
  final String contenido;
  final String? fechaCreacion;
  final String? fechaEnvio;
  final String tipoCarta;
  final String estado;
  final int? expedienteId;
  final int? actividadId;
  final int? apadrinadoId;
  final String? apadrinadoNombre;
  final int? escritoPorId;
  final String? escritoPorNombre;
  final String? observaciones;

  Carta({
    required this.id,
    required this.titulo,
    required this.contenido,
    this.fechaCreacion,
    this.fechaEnvio,
    required this.tipoCarta,
    required this.estado,
    this.expedienteId,
    this.actividadId,
    this.apadrinadoId,
    this.apadrinadoNombre,
    this.escritoPorId,
    this.escritoPorNombre,
    this.observaciones,
  });

  bool get isBorrador => estado == 'BORRADOR';
  bool get isEnviada => estado == 'ENVIADA';
  bool get isRecibida => estado == 'RECIBIDA';
  bool get isAprobada => estado == 'APROBADA';
  bool get isRechazada => estado == 'RECHAZADA';

  factory Carta.fromJson(Map<String, dynamic> json) {
    return Carta(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      titulo: json['titulo'] ?? '',
      contenido: json['contenido'] ?? '',
      fechaCreacion: json['fechaCreacion'],
      fechaEnvio: json['fechaEnvio'],
      tipoCarta: json['tipoCarta'] ?? 'GENERAL',
      estado: json['estado'] ?? 'BORRADOR',
      expedienteId: json['expedienteId'] != null ? int.tryParse(json['expedienteId'].toString()) : null,
      actividadId: json['actividadId'] != null ? int.tryParse(json['actividadId'].toString()) : null,
      apadrinadoId: json['apadrinadoId'] != null ? int.tryParse(json['apadrinadoId'].toString()) : null,
      apadrinadoNombre: json['apadrinadoNombre'],
      escritoPorId: json['escritoPorId'] != null ? int.tryParse(json['escritoPorId'].toString()) : null,
      escritoPorNombre: json['escritoPorNombre'],
      observaciones: json['observaciones'],
    );
  }
}
