import '../core/network/api_client.dart';

/// Perfil del usuario autenticado.
class Perfil {
  final int id;
  final String nombre;
  final String? apellido;
  final String correo;
  final String? telefono;
  final String? direccion;
  final String? fechaNacimiento;
  final String? rolNombre;

  Perfil({
    required this.id,
    required this.nombre,
    this.apellido,
    required this.correo,
    this.telefono,
    this.direccion,
    this.fechaNacimiento,
    this.rolNombre,
  });

  String get nombreCompleto =>
      [nombre, apellido].where((s) => s != null && s.isNotEmpty).join(' ');

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
        id: int.tryParse(json['id'].toString()) ?? 0,
        nombre: json['nombre'] ?? '',
        apellido: json['apellido'],
        correo: json['correo'] ?? '',
        telefono: json['telefono'],
        direccion: json['direccion'],
        fechaNacimiento: json['fechaNacimiento']?.toString(),
        rolNombre: json['rolNombre'],
      );
}

class UsuarioService {
  final ApiService _api = ApiService();

  Future<Perfil> miPerfil() async => Perfil.fromJson(await _api.get('/api/usuarios/me'));

  /// Actualiza la información permitida del perfil (nombre, apellido,
  /// teléfono, dirección y fecha de nacimiento en formato yyyy-MM-dd).
  Future<Perfil> actualizar({
    String? nombre,
    String? apellido,
    String? telefono,
    String? direccion,
    String? fechaNacimiento,
  }) async {
    return Perfil.fromJson(await _api.put('/api/usuarios/me', {
      if (nombre != null) 'nombre': nombre,
      if (apellido != null) 'apellido': apellido,
      if (telefono != null) 'telefono': telefono,
      if (direccion != null) 'direccion': direccion,
      if (fechaNacimiento != null) 'fechaNacimiento': fechaNacimiento,
    }));
  }
}
