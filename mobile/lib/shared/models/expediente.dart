import 'apadrinado.dart';
import 'asignacion.dart';
import 'carta.dart';
import 'documento.dart';
import 'json_utils.dart';

/// Observación del coordinador en el expediente del apadrinado.
class Observacion {
  final int id;
  final int? asignacionId;
  final String? actividadTitulo;
  final String texto;
  final String? autorNombre;
  final String? fecha;

  Observacion({
    required this.id,
    this.asignacionId,
    this.actividadTitulo,
    required this.texto,
    this.autorNombre,
    this.fecha,
  });

  factory Observacion.fromJson(Map<String, dynamic> json) => Observacion(
        id: toInt(json['id']),
        asignacionId: toIntOrNull(json['asignacionId']),
        actividadTitulo: json['actividadTitulo'],
        texto: json['texto'] ?? '',
        autorNombre: json['autorNombre'],
        fecha: json['fecha']?.toString(),
      );
}

/// Expediente digital del apadrinado (solo coordinador).
class Expediente {
  final int id;
  final String? codigo;
  final String? estado;
  final String? fechaCreacion;
  final Apadrinado? apadrinado;
  final List<Asignacion> actividades;
  final List<Documento> documentos;
  final List<Documento> fotografias;
  final List<Carta> cartas;
  final List<Observacion> observaciones;
  final int totalAprobadas;

  Expediente({
    required this.id,
    this.codigo,
    this.estado,
    this.fechaCreacion,
    this.apadrinado,
    this.actividades = const [],
    this.documentos = const [],
    this.fotografias = const [],
    this.cartas = const [],
    this.observaciones = const [],
    this.totalAprobadas = 0,
  });

  int get totalActividades => actividades.length;
  int get totalDocumentos => documentos.length;

  factory Expediente.fromJson(Map<String, dynamic> json) => Expediente(
        id: toInt(json['id']),
        codigo: json['codigo'],
        estado: json['estado'],
        fechaCreacion: json['fechaCreacion']?.toString(),
        apadrinado: json['apadrinado'] is Map
            ? Apadrinado.fromJson(Map<String, dynamic>.from(json['apadrinado']))
            : null,
        actividades: toList(json['actividades'], Asignacion.fromJson),
        documentos: toList(json['documentos'], Documento.fromJson),
        fotografias: toList(json['fotografias'], Documento.fromJson),
        cartas: toList(json['cartas'], Carta.fromJson),
        observaciones: toList(json['observaciones'], Observacion.fromJson),
        totalAprobadas: toInt(json['totalAprobadas']),
      );
}

/// PDF o ZIP generado por el backend.
class Exportacion {
  final int id;
  final String tipo;
  final String nombreArchivo;
  final String? tipoMime;
  final int? tamanioBytes;
  final String? fechaGeneracion;
  final String? fechaExpiracion;
  final bool disponible;
  final String? apadrinadoNombre;
  final String? actividadTitulo;
  final String? fechaDesde;
  final String? fechaHasta;
  final String urlDescarga;

  Exportacion({
    required this.id,
    required this.tipo,
    required this.nombreArchivo,
    this.tipoMime,
    this.tamanioBytes,
    this.fechaGeneracion,
    this.fechaExpiracion,
    this.disponible = true,
    this.apadrinadoNombre,
    this.actividadTitulo,
    this.fechaDesde,
    this.fechaHasta,
    required this.urlDescarga,
  });

  bool get esPdf => tipo.startsWith('PDF');

  factory Exportacion.fromJson(Map<String, dynamic> json) => Exportacion(
        id: toInt(json['id']),
        tipo: json['tipo'] ?? '',
        nombreArchivo: json['nombreArchivo'] ?? 'archivo',
        tipoMime: json['tipoMime'],
        tamanioBytes: toIntOrNull(json['tamanioBytes']),
        fechaGeneracion: json['fechaGeneracion']?.toString(),
        fechaExpiracion: json['fechaExpiracion']?.toString(),
        disponible: toBool(json['disponible']),
        apadrinadoNombre: json['apadrinadoNombre'],
        actividadTitulo: json['actividadTitulo'],
        fechaDesde: json['fechaDesde']?.toString(),
        fechaHasta: json['fechaHasta']?.toString(),
        urlDescarga: json['urlDescarga'] ?? '/api/exportaciones/${json['id']}/descargar',
      );
}
