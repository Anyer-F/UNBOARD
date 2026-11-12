import 'asignacion.dart';
import 'comunidad.dart';
import 'json_utils.dart';

/// Módulo de una comunidad: agrupa sus actividades.
class Modulo {
  final int id;
  final int? comunidadId;
  final String nombre;
  final String? descripcion;
  final int orden;
  final int totalActividades;

  Modulo({
    required this.id,
    this.comunidadId,
    required this.nombre,
    this.descripcion,
    this.orden = 1,
    this.totalActividades = 0,
  });

  factory Modulo.fromJson(Map<String, dynamic> json) => Modulo(
        id: toInt(json['id']),
        comunidadId: toIntOrNull(json['comunidadId']),
        nombre: json['nombre'] ?? '',
        descripcion: json['descripcion'],
        orden: toInt(json['orden'], 1),
        totalActividades: toInt(json['totalActividades']),
      );
}

/// Módulo visto por el apadrinado, con sus actividades separadas.
class ModuloContenido {
  final Modulo modulo;
  final List<Asignacion> enProceso;
  final List<Asignacion> realizadas;
  final List<Asignacion> anuncios;
  final List<Asignacion> material;

  ModuloContenido({
    required this.modulo,
    this.enProceso = const [],
    this.realizadas = const [],
    this.anuncios = const [],
    this.material = const [],
  });

  int get total => enProceso.length + realizadas.length + anuncios.length + material.length;

  factory ModuloContenido.fromJson(Map<String, dynamic> json) => ModuloContenido(
        modulo: Modulo.fromJson(Map<String, dynamic>.from(json['modulo'] ?? {})),
        enProceso: toList(json['enProceso'], Asignacion.fromJson),
        realizadas: toList(json['realizadas'], Asignacion.fromJson),
        anuncios: toList(json['anuncios'], Asignacion.fromJson),
        material: toList(json['material'], Asignacion.fromJson),
      );
}

/// Comunidad del apadrinado con su coordinador y sus módulos.
class MiComunidad {
  final Comunidad comunidad;
  final String? coordinadorNombre;
  final String? coordinadorCorreo;
  final List<ModuloContenido> modulos;

  MiComunidad({
    required this.comunidad,
    this.coordinadorNombre,
    this.coordinadorCorreo,
    this.modulos = const [],
  });

  factory MiComunidad.fromJson(Map<String, dynamic> json) => MiComunidad(
        comunidad: Comunidad.fromJson(Map<String, dynamic>.from(json['comunidad'] ?? {})),
        coordinadorNombre: json['coordinadorNombre'],
        coordinadorCorreo: json['coordinadorCorreo'],
        modulos: toList(json['modulos'], ModuloContenido.fromJson),
      );
}

/// Tablero de pendientes del apadrinado.
class TableroApadrinado {
  final List<Asignacion> pendientes;
  final int correcciones;
  final int proximasAVencer;
  final int realizadas;
  final int anunciosNuevos;

  TableroApadrinado({
    this.pendientes = const [],
    this.correcciones = 0,
    this.proximasAVencer = 0,
    this.realizadas = 0,
    this.anunciosNuevos = 0,
  });

  factory TableroApadrinado.fromJson(Map<String, dynamic> json) => TableroApadrinado(
        pendientes: toList(json['pendientes'], Asignacion.fromJson),
        correcciones: toInt(json['correcciones']),
        proximasAVencer: toInt(json['proximasAVencer']),
        realizadas: toInt(json['realizadas']),
        anunciosNuevos: toInt(json['anunciosNuevos']),
      );
}
