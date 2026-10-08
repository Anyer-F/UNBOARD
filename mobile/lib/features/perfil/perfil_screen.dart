import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/profile_header.dart';
import '../../services/auth_service.dart';
import 'cambiar_contrasena_screen.dart';
import 'editar_perfil_screen.dart';

/// Perfil del usuario (especificación §31).
///
/// Fotografía, nombre, correo, comunidad (cuando corresponda)
/// y rol. Acciones: editar, cambiar contraseña y cerrar sesión.
/// Puede usarse como pestaña embebida ([embedded]) del shell.
class PerfilScreen extends StatelessWidget {
  final bool embedded;

  const PerfilScreen({super.key, this.embedded = false});

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coralRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      await Provider.of<AuthService>(context, listen: false).logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    final content = SingleChildScrollView(
      padding: Responsive.screenPadding(context).copyWith(
            top: AppSpacing.lg,
            bottom: AppSpacing.xxl,
          ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileHeader(
              nombre: user?.nombre ?? 'Usuario',
              correo: user?.correo,
              rol: user?.isCoordinador == true ? 'Coordinador' : 'Apadrinado',
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Información de la cuenta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  InfoTile(
                    icon: Icons.person_outline,
                    label: 'Nombre completo',
                    value: user?.nombre ?? 'No disponible',
                  ),
                  const Divider(height: 1, indent: 60),
                  InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: user?.correo ?? 'No disponible',
                  ),
                  const Divider(height: 1, indent: 60),
                  InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Rol',
                    value: user?.isCoordinador == true ? 'Coordinador' : 'Apadrinado',
                  ),
                  const Divider(height: 1, indent: 60),
                  InfoTile(
                    icon: Icons.location_city_outlined,
                    label: 'Organización',
                    value: 'Fundación UNBOUND',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Configuración',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined,
                        color: AppColors.darkNavy),
                    title: const Text(
                      'Editar perfil',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Actualiza tu información personal'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditarPerfilScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: const Icon(Icons.lock_outlined,
                        color: AppColors.darkNavy),
                    title: const Text(
                      'Cambiar contraseña',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Actualiza tu contraseña de acceso'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CambiarContrasenaScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: const Icon(Icons.info_outline,
                        color: AppColors.darkNavy),
                    title: const Text(
                      'Acerca de',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Versión 1.0.0 • Fundación UNBOUND'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'UNBOUND DMS',
                        applicationVersion: '1.0.0',
                        applicationLegalese:
                            '© 2026 Fundación UNBOUND\nHuehuetenango, Guatemala',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.coralRed),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: AppColors.coralRed),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coralRed,
                  side: const BorderSide(color: AppColors.coralRed),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => _cerrarSesion(context),
              ),
            ),
          ],
        ),
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: content,
    );
  }
}
