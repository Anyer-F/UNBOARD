/// Rutas con nombre de la aplicación.
///
/// La navegación principal utiliza shells con [IndexedStack];
/// estas constantes se usan para navegación contextual
/// (por ejemplo, desde notificaciones).
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const joinCommunity = '/join-community';

  static const apadrinadoHome = '/apadrinado/home';
  static const apadrinadoActividades = '/apadrinado/actividades';
  static const apadrinadoExpediente = '/apadrinado/expediente';
  static const apadrinadoNotificaciones = '/apadrinado/notificaciones';
  static const apadrinadoPerfil = '/apadrinado/perfil';

  static const coordinadorHome = '/coordinador/home';
  static const coordinadorComunidades = '/coordinador/comunidades';
  static const coordinadorActividades = '/coordinador/actividades';
  static const coordinadorApadrinados = '/coordinador/apadrinados';
  static const coordinadorPerfil = '/coordinador/perfil';

  static const actividadDetalle = '/actividad/detalle';
  static const actividadEntrega = '/actividad/entrega';
  static const actividadSeguimiento = '/actividad/seguimiento';
  static const crearActividad = '/actividad/crear';

  static const comunidadDetalle = '/comunidad/detalle';
  static const solicitudes = '/comunidad/solicitudes';

  static const expedienteDetalle = '/expediente/detalle';
  static const documentos = '/documentos';
  static const notificaciones = '/notificaciones';
  static const perfil = '/perfil';

  /// Ruta inicial según el rol del usuario.
  static String initialRoute(bool isCoordinador) =>
      isCoordinador ? coordinadorHome : apadrinadoHome;
}
