import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/apadrinados/join_community_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/recuperar_contrasena_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/dashboard/apadrinado_shell.dart';
import 'features/dashboard/coordinador_shell.dart';
import 'core/network/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Datos de fechas en español (AppDateUtils usa el locale "es")
  await initializeDateFormatting('es');

  // Inicialización del cliente HTTP (carga la URL base
  // y el token guardados localmente).
  final apiService = ApiService();
  await apiService.init();

  // Inicialización de servicios y almacenamiento local
  final authService = AuthService();
  await authService.init();

  // Inicialización de notificaciones push
  final pushNotificationService = PushNotificationService();
  await pushNotificationService.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: authService,
      child: const UnboundApp(),
    ),
  );
}

class UnboundApp extends StatelessWidget {
  const UnboundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNBOUND DMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/login':
            page = const LoginScreen();
          case '/register':
            page = const RegisterScreen();
          case '/recuperar-contrasena':
            page = const RecuperarContrasenaScreen();
          case '/join-community':
            page = const JoinCommunityScreen();
          case '/apadrinado/home':
            page = const ApadrinadoShell();
          case '/coordinador/home':
            page = const CoordinadorShell();
          default:
            page = const SplashScreen();
        }
        return MaterialPageRoute(builder: (_) => page);
      },
    );
  }
}
