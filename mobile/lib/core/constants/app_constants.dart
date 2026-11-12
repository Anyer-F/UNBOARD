/// Constantes generales de la aplicación.
class AppConstants {
  static const String appName = 'UNBOARD';
  static const String appTitle = 'UNBOARD';
  static const String organizacion = 'Fundación UNBOUND';
  static const String sede = 'Huehuetenango';

  // Roles del sistema
  static const String rolApadrinado = 'APADRINADO';
  static const String rolCoordinador = 'COORDINADOR';

  // Estados de una actividad para cada apadrinado (asignación)
  static const String estadoPendiente = 'PENDIENTE';
  static const String estadoEnProgreso = 'EN_PROGRESO';
  static const String estadoEnviado = 'ENVIADO';
  static const String estadoEnRevision = 'EN_REVISION';
  static const String estadoCorreccion = 'CORRECCION_SOLICITADA';
  static const String estadoAprobado = 'APROBADO';
  static const String estadoVencido = 'VENCIDO';
  static const String estadoPublicado = 'PUBLICADO';
  static const String estadoVisto = 'VISTO';

  // Tipos de actividad
  static const String tipoTarea = 'TAREA';
  static const String tipoAnuncio = 'ANUNCIO';
  static const String tipoMaterial = 'MATERIAL_APOYO';

  AppConstants._();
}
