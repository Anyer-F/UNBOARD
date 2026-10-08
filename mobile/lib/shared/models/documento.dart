class Documento {
  final int id;
  final String nombreOriginal;
  final String nombreAlmacenado;
  final String urlDescarga;
  final String? tipoMime;
  final int? tamanioBytes;
  final String? fechaSubida;
  final String tipoDocumento;
  final String? descripcion;
  final int? expedienteId;
  final int? apadrinadoId;
  final String? apadrinadoNombre;
  final int? actividadId;
  final String? actividadTitulo;
  final int? subidoPorUsuarioId;
  final String? subidoPorNombre;

  Documento({
    required this.id,
    required this.nombreOriginal,
    required this.nombreAlmacenado,
    required this.urlDescarga,
    this.tipoMime,
    this.tamanioBytes,
    this.fechaSubida,
    required this.tipoDocumento,
    this.descripcion,
    this.expedienteId,
    this.apadrinadoId,
    this.apadrinadoNombre,
    this.actividadId,
    this.actividadTitulo,
    this.subidoPorUsuarioId,
    this.subidoPorNombre,
  });

  bool get isPdf =>
      tipoMime?.toLowerCase().contains('pdf') == true ||
      nombreOriginal.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      tipoMime?.toLowerCase().startsWith('image/') == true ||
      nombreOriginal.toLowerCase().endsWith('.jpg') ||
      nombreOriginal.toLowerCase().endsWith('.jpeg') ||
      nombreOriginal.toLowerCase().endsWith('.png') ||
      nombreOriginal.toLowerCase().endsWith('.webp');

  bool get isCarta =>
      tipoDocumento == 'CARTA' ||
      nombreOriginal.toLowerCase().contains('carta');

  bool get isText =>
      isCarta ||
      tipoMime?.toLowerCase().startsWith('text/') == true ||
      nombreOriginal.toLowerCase().endsWith('.txt');

  factory Documento.fromJson(Map<String, dynamic> json) {
    return Documento(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombreOriginal: json['nombreOriginal'] ?? '',
      nombreAlmacenado: json['nombreAlmacenado'] ?? '',
      urlDescarga: json['urlDescarga'] ?? '',
      tipoMime: json['tipoMime'],
      tamanioBytes: json['tamanioBytes'] != null ? int.tryParse(json['tamanioBytes'].toString()) : null,
      fechaSubida: json['fechaSubida'],
      tipoDocumento: json['tipoDocumento'] ?? 'OTRO',
      descripcion: json['descripcion'],
      expedienteId: json['expedienteId'] != null ? int.tryParse(json['expedienteId'].toString()) : null,
      apadrinadoId: json['apadrinadoId'] != null ? int.tryParse(json['apadrinadoId'].toString()) : null,
      apadrinadoNombre: json['apadrinadoNombre'],
      actividadId: json['actividadId'] != null ? int.tryParse(json['actividadId'].toString()) : null,
      actividadTitulo: json['actividadTitulo'],
      subidoPorUsuarioId: json['subidoPorUsuarioId'] != null ? int.tryParse(json['subidoPorUsuarioId'].toString()) : null,
      subidoPorNombre: json['subidoPorNombre'],
    );
  }
}
