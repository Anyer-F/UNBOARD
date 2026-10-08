import 'actividad.dart';
import 'apadrinado.dart';
import 'documento.dart';

class Expediente {
  final int id;
  final Apadrinado? apadrinado;
  final String? fechaCreacion;
  final int totalDocumentos;
  final int totalActividades;
  final List<Documento> documentos;
  final List<Actividad> actividades;

  Expediente({
    required this.id,
    this.apadrinado,
    this.fechaCreacion,
    this.totalDocumentos = 0,
    this.totalActividades = 0,
    this.documentos = const [],
    this.actividades = const [],
  });

  factory Expediente.fromJson(Map<String, dynamic> json) {
    var docList = <Documento>[];
    if (json['documentos'] != null && json['documentos'] is List) {
      docList = (json['documentos'] as List)
          .map((d) => Documento.fromJson(d))
          .toList();
    }

    var actList = <Actividad>[];
    if (json['actividades'] != null && json['actividades'] is List) {
      actList = (json['actividades'] as List)
          .map((a) => Actividad.fromJson(a))
          .toList();
    }

    return Expediente(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      apadrinado: json['apadrinado'] != null ? Apadrinado.fromJson(json['apadrinado']) : null,
      fechaCreacion: json['fechaCreacion'],
      totalDocumentos: json['totalDocumentos'] != null ? int.parse(json['totalDocumentos'].toString()) : docList.length,
      totalActividades: json['totalActividades'] != null ? int.parse(json['totalActividades'].toString()) : actList.length,
      documentos: docList,
      actividades: actList,
    );
  }
}
