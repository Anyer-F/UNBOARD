class AuthUser {
  final String token;
  final String tokenType;
  final int usuarioId;
  final String nombre;
  final String correo;
  final String rol;
  final int? coordinadorId;
  final int? apadrinadoId;

  AuthUser({
    required this.token,
    required this.tokenType,
    required this.usuarioId,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.coordinadorId,
    this.apadrinadoId,
  });

  bool get isCoordinador => rol.toLowerCase().contains('coord');
  bool get isApadrinado => rol.toLowerCase().contains('apad');

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      token: json['token'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
      usuarioId: json['usuarioId'] is int ? json['usuarioId'] : (json['usuarioId'] != null ? int.parse(json['usuarioId'].toString()) : 0),
      nombre: json['nombre'] ?? '',
      correo: json['correo'] ?? '',
      rol: json['rol'] ?? '',
      coordinadorId: json['coordinadorId'] != null ? int.tryParse(json['coordinadorId'].toString()) : null,
      apadrinadoId: json['apadrinadoId'] != null ? int.tryParse(json['apadrinadoId'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'tokenType': tokenType,
      'usuarioId': usuarioId,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'coordinadorId': coordinadorId,
      'apadrinadoId': apadrinadoId,
    };
  }
}
