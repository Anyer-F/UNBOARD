import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../services/auth_service.dart';
import '../../../services/notificacion_service.dart';
import '../actividades/coordinador_actividades_screen.dart';
import '../actividades/crear_actividad_screen.dart';
import '../apadrinados/apadrinados_list_screen.dart';
import '../auth/login_screen.dart';
import '../comunidades/comunidades_screen.dart';
import '../perfil/ayuda_screen.dart';
import '../perfil/perfil_screen.dart';
import 'coordinador_dashboard_screen.dart';

/// Shell del Coordinador (especificación §9).
///
/// Navegación inferior persistente:
/// Inicio · Comunidades · Actividades · Apadrinados · Perfil
class CoordinadorShell extends StatefulWidget {
  const CoordinadorShell({super.key});

  @override
  State<CoordinadorShell> createState() => _CoordinadorShellState();
}

class _CoordinadorShellState extends State<CoordinadorShell> {
  int _currentIndex = 0;
  final _notifService = NotificacionService();
  int _noLeidas = 0;

  static const _titulos = [
    'Inicio',
    'Mis Comunidades',
    'Mis Actividades',
    'Mis Apadrinados',
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
              onPressed: () => _irA(4),
            ),
          AccountMenuButton(
            items: const [
              AccountMenuEntry(
                value: 'perfil',
                icon: Icons.person_outline,
                label: 'Mi Perfil',
              ),
              AccountMenuEntry(
                value: 'ayuda',
                icon: Icons.help_outline,
                label: 'Ayuda',
              ),
              AccountMenuDivider(),
              AccountMenuEntry(
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
          CoordinadorHomeContent(onAbrirComunidades: () => _irA(1)),
          const ComunidadesScreen(),
          const CoordinadorActividadesContent(),
          const ApadrinadosListScreen(embedded: true),
          const PerfilScreen(embedded: true),
        ],
      ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () async {
                final creada = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CrearActividadScreen(),
                  ),
                );
                if (creada == true && mounted) {
                  // Recarga la pestaña de actividades
                  setState(() {});
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva Actividad'),
            )
          : null,
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
            icon: Icons.location_city_outlined,
            activeIcon: Icons.location_city,
            label: 'Comunidades',
          ),
          NavigationItem(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            label: 'Actividades',
          ),
          NavigationItem(
            icon: Icons.people_outlined,
            activeIcon: Icons.people,
            label: 'Apadrinados',
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
