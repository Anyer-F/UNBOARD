import 'actividad.dart';
import 'carta.dart';
import 'documento.dart';
import 'json_utils.dart';

/// Estados de una asignación (actividad para un apadrinado).
class EstadoAsignacion {
  static const String pendiente = 'PENDIENTE';
  static const String enProgreso = 'EN_PROGRESO';
  static const String enviado = 'ENVIADO';
  static const String enRevision = 'EN_REVISION';
  static const String correccion = 'CORRECCION_SOLICITADA';
  static const String aprobado = 'APROBADO';
  static const String vencido = 'VENCIDO';
  static const String publicado = 'PUBLICADO';
  static const String visto = 'VISTO';

  EstadoAsignacion._();
}

/// Actividad asignada a un apadrinado, con su estado individual.
class Asignacion {
  final int id;
  final int? actividadId;
  final int? apadrinadoId;
  final String? apadrinadoNombre;
  final String estado;
  final String? fechaAsignacion;
  final String? fechaInicio;
  final String? fechaEnvio;
  final String? fechaAprobacion;
  final String? fechaVisto;
  final int? versionActual;
  final String? ultimaSugerencia;
  final bool proximaAVencer;
  final Actividad? actividad;

  Asignacion({
    required this.id,
    this.actividadId,
    this.apadrinadoId,
    this.apadrinadoNombre,
    required this.estado,
    this.fechaAsignacion,
    this.fechaInicio,
    this.fechaEnvio,
    this.fechaAprobacion,
    this.fechaVisto,
    this.versionActual,
    this.ultimaSugerencia,
    this.proximaAVencer = false,
    this.actividad,
  });

  bool get enCorreccion => estado == EstadoAsignacion.correccion;
  bool get aprobada => estado == EstadoAsignacion.aprobado;

  /// Entrega recibida que espera revisión del coordinador.
  bool get porRevisar => estado == EstadoAsignacion.enviado || estado == EstadoAsignacion.enRevision;

  factory Asignacion.fromJson(Map<String, dynamic> json) => Asignacion(
        id: toInt(json['id']),
        actividadId: toIntOrNull(json['actividadId']),
        apadrinadoId: toIntOrNull(json['apadrinadoId']),
        apadrinadoNombre: json['apadrinadoNombre'],
        estado: json['estado'] ?? EstadoAsignacion.pendiente,
        fechaAsignacion: json['fechaAsignacion']?.toString(),
        fechaInicio: json['fechaInicio']?.toString(),
        fechaEnvio: json['fechaEnvio']?.toString(),
        fechaAprobacion: json['fechaAprobacion']?.toString(),
        fechaVisto: json['fechaVisto']?.toString(),
        versionActual: toIntOrNull(json['versionActual']),
        ultimaSugerencia: json['ultimaSugerencia'],
        proximaAVencer: toBool(json['proximaAVencer']),
        actividad: json['actividad'] is Map
            ? Actividad.fromJson(Map<String, dynamic>.from(json['actividad']))
            : null,
      );
}

/// Sugerencia de mejora del coordinador sobre una versión de la entrega.
class Sugerencia {
  final int id;
  final int? entregaId;
  final int? version;
  final String texto;
  final String? autorNombre;
  final String? fecha;

  Sugerencia({
    required this.id,
    this.entregaId,
    this.version,
    required this.texto,
    this.autorNombre,
    this.fecha,
  });

  factory Sugerencia.fromJson(Map<String, dynamic> json) => Sugerencia(
        id: toInt(json['id']),
        entregaId: toIntOrNull(json['entregaId']),
        version: toIntOrNull(json['version']),
        texto: json['texto'] ?? '',
        autorNombre: json['autorNombre'],
        fecha: json['fecha']?.toString(),
      );
}

/// Versión de la entrega de una tarea.
class Entrega {
  final int id;
  final int? asignacionId;
  final int version;
  final String estado;
  final String? comentario;
  final String? fechaCreacion;
  final String? fechaEnvio;
  final String? fechaRevision;
  final String? revisorNombre;
  final List<Documento> documentos;
  final List<Carta> cartas;
  final List<Sugerencia> sugerencias;

  Entrega({
    required this.id,
    this.asignacionId,
    required this.version,
    required this.estado,
    this.comentario,
    this.fechaCreacion,
    this.fechaEnvio,
    this.fechaRevision,
    this.revisorNombre,
    this.documentos = const [],
    this.cartas = const [],
    this.sugerencias = const [],
  });

  bool get esBorrador => estado == 'BORRADOR';
  List<Documento> get fotografias => documentos.where((d) => d.isImage).toList();
  List<Documento> get archivos => documentos.where((d) => !d.isImage).toList();

  factory Entrega.fromJson(Map<String, dynamic> json) => Entrega(
        id: toInt(json['id']),
        asignacionId: toIntOrNull(json['asignacionId']),
        version: toInt(json['version'], 1),
        estado: json['estado'] ?? 'BORRADOR',
        comentario: json['comentario'],
        fechaCreacion: json['fechaCreacion']?.toString(),
        fechaEnvio: json['fechaEnvio']?.toString(),
        fechaRevision: json['fechaRevision']?.toString(),
        revisorNombre: json['revisorNombre'],
        documentos: toList(json['documentos'], Documento.fromJson),
        cartas: toList(json['cartas'], Carta.fromJson),
        sugerencias: toList(json['sugerencias'], Sugerencia.fromJson),
      );
}

/// Asignación con la actividad, el material del coordinador y todas
/// las versiones de la entrega (la más reciente primero).
class AsignacionDetalle {
  final Asignacion asignacion;
  final Actividad actividad;
  final List<Entrega> entregas;

  /// El apadrinado puede modificar y enviar su entrega.
  final bool editable;

  AsignacionDetalle({
    required this.asignacion,
    required this.actividad,
    this.entregas = const [],
    this.editable = false,
  });

  Entrega? get ultima => entregas.isNotEmpty ? entregas.first : null;

  /// Borrador en preparación (si existe).
  Entrega? get borrador => ultima != null && ultima!.esBorrador ? ultima : null;

  /// Última versión enviada al coordinador (excluye el borrador).
  Entrega? get ultimaEnviada {
    for (final e in entregas) {
      if (!e.esBorrador) return e;
    }
    return null;
  }

  List<Sugerencia> get sugerencias {
    final todas = <Sugerencia>[];
    for (final e in entregas.reversed) {
      todas.addAll(e.sugerencias);
    }
    return todas;
  }

  factory AsignacionDetalle.fromJson(Map<String, dynamic> json) => AsignacionDetalle(
        asignacion: Asignacion.fromJson(Map<String, dynamic>.from(json['asignacion'] ?? {})),
        actividad: Actividad.fromJson(Map<String, dynamic>.from(json['actividad'] ?? {})),
        entregas: toList(json['entregas'], Entrega.fromJson),
        editable: toBool(json['editable']),
      );
}

/// Detalle de una actividad para el coordinador.
class ActividadDetalle {
  final Actividad actividad;
  final List<Asignacion> asignaciones;

  /// Tiene entregas enviadas: eliminarla será lógica.
  final bool tieneEntregas;

  /// Tarea con al menos una entrega aprobada (se puede exportar PDF / ZIP).
  final bool exportable;

  ActividadDetalle({
    required this.actividad,
    this.asignaciones = const [],
    this.tieneEntregas = false,
    this.exportable = false,
  });

  factory ActividadDetalle.fromJson(Map<String, dynamic> json) => ActividadDetalle(
        actividad: Actividad.fromJson(Map<String, dynamic>.from(json['actividad'] ?? {})),
        asignaciones: toList(json['asignaciones'], Asignacion.fromJson),
        tieneEntregas: toBool(json['tieneEntregas']),
        exportable: toBool(json['exportable']),
      );
}
