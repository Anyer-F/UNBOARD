import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/comunidad_service.dart';
import '../../services/usuario_service.dart';
import '../../shared/models/modulo.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/profile_header.dart';
import 'cambiar_contrasena_screen.dart';
import 'editar_perfil_screen.dart';

/// Perfil del usuario (ambos roles).
///
/// Datos personales, rol y, para el apadrinado, su comunidad y
/// coordinador responsable. Acciones: editar, cambiar contraseña y
/// cerrar sesión. Puede usarse como pestaña embebida ([embedded]).
class PerfilScreen extends StatefulWidget {
  final bool embedded;

  const PerfilScreen({super.key, this.embedded = false});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Perfil? _perfil;
  MiComunidad? _comunidad;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    try {
      final perfil = await UsuarioService().miPerfil();
      if (mounted) setState(() => _perfil = perfil);
    } catch (_) {
      // Se muestran los datos de la sesión
    }
    if (user != null && user.isApadrinado && user.apadrinadoId != null) {
      try {
        final comunidad = await ComunidadService().miComunidad();
        if (mounted) setState(() => _comunidad = comunidad);
      } catch (_) {}
    }
  }

  Future<void> _editar() async {
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditarPerfilScreen()),
    );
    if (cambio == true && mounted) _cargar();
  }

  Future<void> _cerrarSesion() async {
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

    if (confirmar == true && mounted) {
      await Provider.of<AuthService>(context, listen: false).logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  static String _valor(String? v) => v != null && v.trim().isNotEmpty ? v : 'No registrado';

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final p = _perfil;
    final rol = user?.isCoordinador == true ? 'Coordinador' : 'Apadrinado';
    final nombre = p?.nombreCompleto.isNotEmpty == true ? p!.nombreCompleto : (user?.nombre ?? 'Usuario');

    const tituloEstilo = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.charcoal);

    // Pantallas anchas: [principal] y [secundario] lado a lado;
    // en teléfono se apilan en una sola columna centrada.
    final principal = <Widget>[
      ProfileHeader(
        nombre: nombre,
        correo: p?.correo ?? user?.correo,
        comunidad: _comunidad?.comunidad.nombre,
        rol: rol,
      ),
      const SizedBox(height: AppSpacing.xl),
      const Text('Información de la cuenta', style: tituloEstilo),
      const SizedBox(height: AppSpacing.md),
      Card(
        child: Column(
          children: [
            InfoTile(icon: Icons.person_outline, label: 'Nombre completo', value: nombre),
            const Divider(height: 1, indent: 60),
            InfoTile(
              icon: Icons.email_outlined,
              label: 'Correo electrónico',
              value: p?.correo ?? user?.correo ?? 'No disponible',
            ),
            const Divider(height: 1, indent: 60),
            InfoTile(icon: Icons.phone_outlined, label: 'Teléfono', value: _valor(p?.telefono)),
            const Divider(height: 1, indent: 60),
            InfoTile(icon: Icons.home_outlined, label: 'Dirección', value: _valor(p?.direccion)),
            const Divider(height: 1, indent: 60),
            InfoTile(
              icon: Icons.cake_outlined,
              label: 'Fecha de nacimiento',
              value: p?.fechaNacimiento != null ? AppDateUtils.formatDate(p!.fechaNacimiento) : 'No registrada',
            ),
            const Divider(height: 1, indent: 60),
            InfoTile(icon: Icons.badge_outlined, label: 'Rol', value: rol),
            const Divider(height: 1, indent: 60),
            const InfoTile(
              icon: Icons.location_city_outlined,
              label: 'Organización',
              value: 'Fundación UNBOUND',
            ),
          ],
        ),
      ),
      if (_comunidad != null) ...[
        const SizedBox(height: AppSpacing.xl),
        const Text('Mi comunidad', style: tituloEstilo),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: [
              InfoTile(
                icon: Icons.groups_outlined,
                label: 'Comunidad',
                value: [_comunidad!.comunidad.nombre, _comunidad!.comunidad.ubicacion]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
              ),
              const Divider(height: 1, indent: 60),
              InfoTile(
                icon: Icons.support_agent_outlined,
                label: 'Coordinador responsable',
                value: [_comunidad!.coordinadorNombre ?? 'Sin asignar', _comunidad!.coordinadorCorreo]
                    .whereType<String>()
                    .join(' · '),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
    ];

    final secundario = <Widget>[
      const Text('Configuración', style: tituloEstilo),
      const SizedBox(height: AppSpacing.md),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.darkNavy),
              title: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Actualiza tu información personal'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: _editar,
            ),
            const Divider(height: 1, indent: 60),
            ListTile(
              leading: const Icon(Icons.lock_outlined, color: AppColors.darkNavy),
              title: const Text('Cambiar contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Actualiza tu contraseña de acceso'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CambiarContrasenaScreen()),
                );
              },
            ),
            const Divider(height: 1, indent: 60),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.darkNavy),
              title: const Text('Acerca de', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Versión 1.0.0 • Fundación UNBOUND'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'UNBOARD',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 Fundación UNBOUND\nHuehuetenango, Guatemala',
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
          label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.coralRed)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coralRed,
            side: const BorderSide(color: AppColors.coralRed),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          onPressed: _cerrarSesion,
        ),
      ),
    ];

    final content = DashboardLayout(
      onRefresh: _cargar,
      principal: principal,
      secundario: secundario,
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: content,
    );
  }
}
