import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/models/expediente.dart';
import '../../../shared/models/notificacion.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/actividad_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/expediente_service.dart';
import '../../../services/notificacion_service.dart';
import '../actividades/actividad_entrega_screen.dart';
import '../expediente/expediente_screen.dart';

/// Dashboard del Apadrinado (especificación §14).
///
/// Pantalla sin saturación: saludo, resumen de comunidad,
/// actividad próxima, acceso al expediente y notificaciones
/// recientes. Tarjetas compactas con solo la información
/// necesaria para decidir si abrirlas.
class ApadrinadoHomeContent extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const ApadrinadoHomeContent({super.key, this.onRefreshRequested});

  @override
  State<ApadrinadoHomeContent> createState() => _ApadrinadoHomeContentState();
}

class _ApadrinadoHomeContentState extends State<ApadrinadoHomeContent> {
  final _actividadService = ActividadService();
  final _expedienteService = ExpedienteService();
  final _notifService = NotificacionService();

  List<Actividad> _actividades = [];
  List<Notificacion> _notificaciones = [];
  Expediente? _expediente;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.apadrinadoId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final acts = await _actividadService.listarPorApadrinado(user!.apadrinadoId!);
      final exp = await _expedienteService.obtenerPorApadrinadoId(user.apadrinadoId!);
      final notifs = await _notifService.listarPorUsuario(user.usuarioId);

      if (mounted) {
        setState(() {
          _actividades = acts;
          _expediente = exp;
          _notificaciones = notifs.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<Actividad> get _pendientes => _actividades
      .where((a) =>
          a.estado == 'PENDIENTE' ||
          a.estado == 'EN_PROCESO' ||
          a.estado == 'CORRECCION_SOLICITADA')
      .toList();

  Actividad? get _proximaActividad {
    final pendientes = List<Actividad>.from(_pendientes);
    pendientes.sort((a, b) {
      final fa = a.fechaLimite ?? '9999';
      final fb = b.fechaLimite ?? '9999';
      return fa.compareTo(fb);
    });
    return pendientes.isNotEmpty ? pendientes.first : null;
  }

  String get _comunidad =>
      _expediente?.apadrinado?.comunidadNombre ?? 'No asignada';

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    if (_isLoading) {
      return const LoadingState(message: 'Cargando tu información...');
    }

    if (_error != null && _actividades.isEmpty) {
      return ErrorState(
        title: 'No se pudieron cargar tus datos',
        message: _error,
        onRetry: _cargarDatos,
      );
    }

    final proxima = _proximaActividad;

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
              // Saludo
              ProfileHeader(
                nombre: '¡Hola, ${user?.nombre ?? "Apadrinado"}!',
                correo: 'Comunidad: $_comunidad',
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actividad próxima
              if (proxima != null) ...[
                const SectionHeader(
                  title: 'Actividad próxima',
                  subtitle: 'Requiere tu atención',
                ),
                ActivityCard(
                  actividad: proxima,
                  showProgress: true,
                  completedItems: 0,
                  totalItems: 1,
                  onTap: () async {
                    final enviada = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActividadEntregaScreen(
                          actividad: proxima,
                        ),
                      ),
                    );
                    if (enviada == true) _cargarDatos();
                  },
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                const EmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Sin actividades pendientes',
                  description: 'Cuando te asignen una actividad aparecerá aquí',
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              // Resumen
              const SectionHeader(
                title: 'Mi resumen',
                subtitle: 'Estado general de tus actividades',
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Pendientes',
                      value: '${_pendientes.length}',
                      icon: Icons.assignment_late_outlined,
                      color: AppColors.mustardGold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MetricCard(
                      label: 'Completadas',
                      value: '${_actividades.length - _pendientes.length}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.sageGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Expediente digital
              const SectionHeader(
                title: 'Mi expediente digital',
                subtitle: 'Tu carpeta digital organizada',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpedienteScreen(),
                    ),
                  );
                },
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.darkNavy.withAlpha(13),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.folder_shared_outlined,
                            color: AppColors.darkNavy,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ver mi expediente',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                'Documentos, fotografías, cartas y evidencias',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _ExpedienteShortcut(
                          icon: Icons.description_outlined,
                          label: 'Documentos',
                          color: AppColors.darkNavy,
                        ),
                        _ExpedienteShortcut(
                          icon: Icons.photo_library_outlined,
                          label: 'Fotografías',
                          color: AppColors.tealCyan,
                        ),
                        _ExpedienteShortcut(
                          icon: Icons.mail_outline,
                          label: 'Cartas',
                          color: AppColors.mustardGold,
                        ),
                        _ExpedienteShortcut(
                          icon: Icons.verified_outlined,
                          label: 'Evidencias',
                          color: AppColors.sageGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Notificaciones recientes
              if (_notificaciones.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Notificaciones recientes',
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._notificaciones.map(
                  (notif) => NotificationCard(notificacion: notif),
                ),
              ],
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
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withAlpha(204),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpedienteShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ExpedienteShortcut({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withAlpha(26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
      fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
