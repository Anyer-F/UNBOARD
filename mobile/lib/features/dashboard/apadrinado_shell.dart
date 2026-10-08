import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../services/auth_service.dart';
import '../../../services/notificacion_service.dart';
import '../actividades/actividades_screen.dart';
import '../auth/login_screen.dart';
import '../expediente/expediente_screen.dart';
import '../notificaciones/notificaciones_screen.dart';
import '../perfil/ayuda_screen.dart';
import '../perfil/perfil_screen.dart';
import 'apadrinado_home_screen.dart';

/// Shell del Apadrinado (especificación §8).
///
/// Navegación inferior persistente:
/// Inicio · Actividades · Expediente · Notificaciones · Perfil
class ApadrinadoShell extends StatefulWidget {
  const ApadrinadoShell({super.key});

  @override
  State<ApadrinadoShell> createState() => _ApadrinadoShellState();
}

class _ApadrinadoShellState extends State<ApadrinadoShell> {
  int _currentIndex = 0;
  final _notifService = NotificacionService();
  int _noLeidas = 0;

  static const _titulos = [
    'Inicio',
    'Mis Actividades',
    'Mi Expediente',
    'Notificaciones',
    'Mi Perfil',
  ];

  @override
  void initState() {
    super.initState();
    _cargarNoLeidas();
  }

  Future<void> _cargarNoLeidas() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    try {
      final count = await _notifService.contarNoLeidas(user.usuarioId);
      if (mounted) setState(() => _noLeidas = count);
    } catch (_) {}
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showConfirmationDialog(
      context,
      title: 'Cerrar Sesión',
      message: '¿Estás seguro de que deseas salir de tu cuenta?',
      confirmLabel: 'Cerrar Sesión',
      isDanger: true,
      icon: Icons.logout,
    );

    if (confirmar && mounted) {
      await Provider.of<AuthService>(context, listen: false).logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  void _irA(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_currentIndex]),
        actions: [
          if (_currentIndex == 0)
            NotificationIconButton(
              count: _noLeidas,
              onPressed: () => _irA(3),
            ),
          AccountMenuButton(
            items: [
              const AccountMenuEntry(
                value: 'perfil',
                icon: Icons.person_outline,
                label: 'Mi Perfil',
              ),
              const AccountMenuEntry(
                value: 'ayuda',
                icon: Icons.help_outline,
                label: 'Ayuda',
              ),
              const AccountMenuDivider(),
              const AccountMenuEntry(
                value: 'logout',
                icon: Icons.logout,
                label: 'Cerrar Sesión',
                iconColor: AppColors.coralRed,
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'perfil':
                  _irA(4);
                case 'ayuda':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AyudaScreen(),
                    ),
                  );
                case 'logout':
                  _cerrarSesion();
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ApadrinadoHomeContent(onRefreshRequested: _cargarNoLeidas),
          const ApadrinadoActividadesContent(),
          const ExpedienteScreen(),
          const NotificacionesScreen(embedded: true),
          const PerfilScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _irA,
        items: const [
          NavigationItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Inicio',
          ),
          NavigationItem(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            label: 'Actividades',
          ),
          NavigationItem(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder,
            label: 'Expediente',
          ),
          NavigationItem(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: 'Notificaciones',
          ),
          NavigationItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
