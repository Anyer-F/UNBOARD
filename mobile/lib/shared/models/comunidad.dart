import 'json_utils.dart';

class Comunidad {
  final int id;
  final String nombre;
  final String? municipio;
  final String? departamento;

  /// SOLICITUD (el coordinador revisa) o DIRECTO (el código basta).
  final String modoIncorporacion;
  final int? totalApadrinados;
  final int? totalModulos;
  final String? coordinadorNombre;

  Comunidad({
    required this.id,
    required this.nombre,
    this.municipio,
    this.departamento,
    this.modoIncorporacion = 'SOLICITUD',
    this.totalApadrinados,
    this.totalModulos,
    this.coordinadorNombre,
  });

  bool get ingresoDirecto => modoIncorporacion == 'DIRECTO';

  String get ubicacion =>
      [municipio, departamento].where((s) => s != null && s.isNotEmpty).join(', ');

  factory Comunidad.fromJson(Map<String, dynamic> json) {
    return Comunidad(
      id: toInt(json['id']),
      nombre: json['nombre'] ?? '',
      municipio: json['municipio'],
      departamento: json['departamento'],
      modoIncorporacion: json['modoIncorporacion'] ?? 'SOLICITUD',
      totalApadrinados: toIntOrNull(json['totalApadrinados']),
      totalModulos: toIntOrNull(json['totalModulos']),
      coordinadorNombre: json['coordinadorNombre'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'municipio': municipio,
      'departamento': departamento,
      'modoIncorporacion': modoIncorporacion,
    };
  }
}
