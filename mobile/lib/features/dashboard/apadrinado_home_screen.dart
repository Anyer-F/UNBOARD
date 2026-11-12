import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/asignacion.dart';
import '../../../shared/models/modulo.dart' show TableroApadrinado;
import '../../../shared/models/notificacion.dart';
import '../../../shared/widgets/actividad_widgets.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/asignacion_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/comunidad_service.dart';
import '../../../services/notificacion_service.dart';
import '../actividades/asignacion_screen.dart';

/// Inicio del apadrinado: tablero de pendientes.
///
/// Muestra las tareas Pendientes, En progreso y con Corrección
/// solicitada ordenadas por fecha límite, destacando las próximas a
/// vencer y las que tienen correcciones del coordinador.
class ApadrinadoHomeContent extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  /// Abre la pestaña "Mi comunidad".
  final VoidCallback? onVerComunidad;

  const ApadrinadoHomeContent({super.key, this.onRefreshRequested, this.onVerComunidad});

  @override
  State<ApadrinadoHomeContent> createState() => _ApadrinadoHomeContentState();
}

class _ApadrinadoHomeContentState extends State<ApadrinadoHomeContent> {
  final _asignacionService = AsignacionService();
  final _comunidadService = ComunidadService();
  final _notifService = NotificacionService();

  TableroApadrinado? _tablero;
  String? _comunidad;
  List<Notificacion> _notificaciones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    setState(() {
      _cargando = _tablero == null;
      _error = null;
    });
    try {
      final tablero = await _asignacionService.tablero();
      String? comunidad = _comunidad;
      try {
        comunidad ??= (await _comunidadService.miComunidad()).comunidad.nombre;
      } catch (_) {}
      List<Notificacion> notificaciones = [];
      if (user != null) {
        try {
          notificaciones = (await _notifService.listarPorUsuario(user.usuarioId)).take(3).toList();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _tablero = tablero;
        _comunidad = comunidad;
        _notificaciones = notificaciones;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeDeError(e);
        _cargando = false;
      });
    }
    widget.onRefreshRequested?.call();
  }

  Future<void> _abrir(Asignacion s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AsignacionScreen(asignacionId: s.id)),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const LoadingState(message: 'Cargando tus actividades...');
    if (_error != null && _tablero == null) {
      return ErrorState(title: 'No se pudo cargar el inicio', message: _error, onRetry: _cargar);
    }
    final user = Provider.of<AuthService>(context).currentUser;
    return ApadrinadoHomeView(
      nombre: user?.nombre ?? 'Apadrinado',
      comunidad: _comunidad,
      tablero: _tablero ?? TableroApadrinado(),
      notificaciones: _notificaciones,
      onRefresh: _cargar,
      onAbrirAsignacion: _abrir,
      onVerComunidad: widget.onVerComunidad,
    );
  }
}

/// Vista del inicio del apadrinado (sin estado, para poder probarla).
class ApadrinadoHomeView extends StatelessWidget {
  final String nombre;
  final String? comunidad;
  final TableroApadrinado tablero;
  final List<Notificacion> notificaciones;
  final Future<void> Function() onRefresh;
  final void Function(Asignacion)? onAbrirAsignacion;
  final VoidCallback? onVerComunidad;

  const ApadrinadoHomeView({
    super.key,
    required this.nombre,
    this.comunidad,
    required this.tablero,
    this.notificaciones = const [],
    required this.onRefresh,
    this.onAbrirAsignacion,
    this.onVerComunidad,
  });

  @override
  Widget build(BuildContext context) {
    final pendientes = tablero.pendientes;
    // Las tarjetas ya traen su propio margen horizontal
    const sinMargen = EdgeInsets.symmetric(vertical: AppSpacing.xs);

    return DashboardLayout(
      onRefresh: onRefresh,
      principal: [
        ProfileHeader(
          nombre: '¡Hola, $nombre!',
          nombreAvatar: nombre,
          comunidad: comunidad,
          rol: 'Apadrinado',
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'Mis pendientes',
          subtitle: pendientes.isEmpty
              ? 'No tienes tareas por realizar'
              : 'Ordenadas por fecha límite',
        ),
        if (tablero.correcciones > 0 || tablero.proximasAVencer > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _Aviso(correcciones: tablero.correcciones, proximas: tablero.proximasAVencer),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (pendientes.isEmpty)
          const EmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: '¡Estás al día!',
            description: 'Cuando tu coordinador te asigne una tarea aparecerá aquí.',
          )
        else
          for (final s in pendientes)
            AsignacionCard(
              asignacion: s,
              margin: sinMargen,
              onTap: onAbrirAsignacion == null ? null : () => onAbrirAsignacion!(s),
            ),
        const SizedBox(height: AppSpacing.xl),
      ],
      secundario: [
        const SectionHeader(title: 'Mi resumen', subtitle: 'Estado de tus actividades'),
        const SizedBox(height: AppSpacing.sm),
        MetricRow(
          children: [
            _MetricCard(
              label: 'Pendientes',
              value: '${pendientes.length}',
              icon: Icons.assignment_late_outlined,
              color: AppColors.mustardGold,
            ),
            _MetricCard(
              label: 'Correcciones',
              value: '${tablero.correcciones}',
              icon: Icons.edit_note_outlined,
              color: AppColors.coralRed,
            ),
            _MetricCard(
              label: 'Por vencer',
              value: '${tablero.proximasAVencer}',
              icon: Icons.alarm_outlined,
              color: AppColors.brownCocoa,
            ),
            _MetricCard(
              label: 'Realizadas',
              value: '${tablero.realizadas}',
              icon: Icons.check_circle_outline,
              color: AppColors.sageGreen,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'Mi comunidad',
          subtitle: tablero.anunciosNuevos > 0
              ? '${tablero.anunciosNuevos} anuncio(s) o material sin ver'
              : 'Módulos, anuncios y material de apoyo',
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccesoComunidad(comunidad: comunidad, nuevos: tablero.anunciosNuevos, onTap: onVerComunidad),
        if (notificaciones.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Notificaciones recientes'),
          const SizedBox(height: AppSpacing.sm),
          for (final n in notificaciones) NotificationCard(notificacion: n),
        ],
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final int correcciones;
  final int proximas;

  const _Aviso({required this.correcciones, required this.proximas});

  @override
  Widget build(BuildContext context) {
    final partes = [
      if (correcciones > 0) '$correcciones con correcciones solicitadas',
      if (proximas > 0) '$proximas próxima(s) a vencer',
    ];
    final color = correcciones > 0 ? AppColors.coralRed : AppColors.mustardGold;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.priority_high_rounded, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Tienes ${partes.join(' y ')}.',
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccesoComunidad extends StatelessWidget {
  final String? comunidad;
  final int nuevos;
  final VoidCallback? onTap;

  const _AccesoComunidad({this.comunidad, required this.nuevos, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tealCyan.withAlpha(15),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.tealCyan, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comunidad ?? 'Mi comunidad',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Ver módulos y actividades',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (nuevos > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.coralRed,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('$nuevos',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color.withAlpha(204), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
