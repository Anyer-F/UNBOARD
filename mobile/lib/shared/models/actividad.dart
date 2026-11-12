import 'documento.dart';
import 'json_utils.dart';

/// Tipos de actividad: solo las tareas requieren entrega y aprobación.
class TipoActividad {
  static const String tarea = 'TAREA';
  static const String anuncio = 'ANUNCIO';
  static const String material = 'MATERIAL_APOYO';

  static const List<String> todos = [tarea, anuncio, material];

  static String etiqueta(String? tipo) {
    switch (tipo) {
      case anuncio:
        return 'Anuncio';
      case material:
        return 'Material de apoyo';
      default:
        return 'Tarea';
    }
  }

  TipoActividad._();
}

/// Avance de una actividad: cantidad de apadrinados en cada estado.
class ResumenAvance {
  final int asignados;
  final int pendientes;
  final int enProgreso;
  final int enviados;
  final int enRevision;
  final int correcciones;
  final int aprobados;
  final int vencidos;
  final int publicados;
  final int vistos;

  const ResumenAvance({
    this.asignados = 0,
    this.pendientes = 0,
    this.enProgreso = 0,
    this.enviados = 0,
    this.enRevision = 0,
    this.correcciones = 0,
    this.aprobados = 0,
    this.vencidos = 0,
    this.publicados = 0,
    this.vistos = 0,
  });

  /// Entregas recibidas que esperan revisión del coordinador.
  int get porRevisar => enviados + enRevision;

  factory ResumenAvance.fromJson(Map<String, dynamic> json) => ResumenAvance(
        asignados: toInt(json['asignados']),
        pendientes: toInt(json['pendientes']),
        enProgreso: toInt(json['enProgreso']),
        enviados: toInt(json['enviados']),
        enRevision: toInt(json['enRevision']),
        correcciones: toInt(json['correcciones']),
        aprobados: toInt(json['aprobados']),
        vencidos: toInt(json['vencidos']),
        publicados: toInt(json['publicados']),
        vistos: toInt(json['vistos']),
      );
}

/// Actividad creada por el coordinador dentro de un módulo de una
/// comunidad. El estado de cada apadrinado está en su asignación.
class Actividad {
  final int id;
  final String tipo;
  final String titulo;
  final String? descripcion;
  final String? instrucciones;
  final String? fechaCreacion;
  final String? fechaActualizacion;
  final String? fechaLimite;
  final bool requiereDocumento;
  final bool requiereFotografia;
  final bool requiereCarta;
  final String? otrosRequisitos;
  final int? comunidadId;
  final String? comunidadNombre;
  final int? moduloId;
  final String? moduloNombre;
  final int? coordinadorId;
  final String? coordinadorNombre;
  final bool asignadaAComunidad;
  final bool eliminada;
  final List<Documento> adjuntos;
  final ResumenAvance? resumen;

  Actividad({
    required this.id,
    this.tipo = TipoActividad.tarea,
    required this.titulo,
    this.descripcion,
    this.instrucciones,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.fechaLimite,
    this.requiereDocumento = false,
    this.requiereFotografia = false,
    this.requiereCarta = false,
    this.otrosRequisitos,
    this.comunidadId,
    this.comunidadNombre,
    this.moduloId,
    this.moduloNombre,
    this.coordinadorId,
    this.coordinadorNombre,
    this.asignadaAComunidad = false,
    this.eliminada = false,
    this.adjuntos = const [],
    this.resumen,
  });

  bool get esTarea => tipo == TipoActividad.tarea;
  bool get esAnuncio => tipo == TipoActividad.anuncio;
  bool get esMaterial => tipo == TipoActividad.material;
  String get tipoTexto => TipoActividad.etiqueta(tipo);

  /// Requisitos de entrega en texto (solo tareas).
  List<String> get requisitos => [
        if (requiereDocumento) 'Documento',
        if (requiereFotografia) 'Fotografía',
        if (requiereCarta) 'Carta',
        if (otrosRequisitos != null && otrosRequisitos!.isNotEmpty) otrosRequisitos!,
      ];

  factory Actividad.fromJson(Map<String, dynamic> json) => Actividad(
        id: toInt(json['id']),
        tipo: json['tipo'] ?? TipoActividad.tarea,
        titulo: json['titulo'] ?? '',
        descripcion: json['descripcion'],
        instrucciones: json['instrucciones'],
        fechaCreacion: json['fechaCreacion']?.toString(),
        fechaActualizacion: json['fechaActualizacion']?.toString(),
        fechaLimite: json['fechaLimite']?.toString(),
        requiereDocumento: toBool(json['requiereDocumento']),
        requiereFotografia: toBool(json['requiereFotografia']),
        requiereCarta: toBool(json['requiereCarta']),
        otrosRequisitos: json['otrosRequisitos'],
        comunidadId: toIntOrNull(json['comunidadId']),
        comunidadNombre: json['comunidadNombre'],
        moduloId: toIntOrNull(json['moduloId']),
        moduloNombre: json['moduloNombre'],
        coordinadorId: toIntOrNull(json['coordinadorId']),
        coordinadorNombre: json['coordinadorNombre'],
        asignadaAComunidad: toBool(json['asignadaAComunidad']),
        eliminada: toBool(json['eliminada']),
        adjuntos: toList(json['adjuntos'], Documento.fromJson),
        resumen: json['resumen'] is Map
            ? ResumenAvance.fromJson(Map<String, dynamic>.from(json['resumen']))
            : null,
      );
}
