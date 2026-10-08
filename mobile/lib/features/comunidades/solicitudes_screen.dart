import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/comunidad.dart';
import '../../../shared/models/solicitud_incorporacion.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../services/expediente_service.dart';

/// Solicitudes de incorporación a una comunidad (especificación §24).
///
/// Lista de personas que desean ingresar. Cada tarjeta muestra
/// fotografía, nombre, información básica y fecha.
/// Acciones: Ver perfil, Rechazar, Aceptar (con confirmación).
class SolicitudesScreen extends StatefulWidget {
  final Comunidad comunidad;

  const SolicitudesScreen({
    super.key,
    required this.comunidad,
  });

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  final _expedienteService = ExpedienteService();

  List<SolicitudIncorporacion> _solicitudes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final solicitudes =
          await _expedienteService.listarSolicitudes(widget.comunidad.id);
      if (mounted) {
        setState(() {
          _solicitudes = solicitudes;
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

  Future<void> _responder(
    SolicitudIncorporacion solicitud, {
    required bool aceptar,
  }) async {
    final confirmar = await showConfirmationDialog(
      context,
      title: aceptar ? 'Aceptar solicitud' : 'Rechazar solicitud',
      message: aceptar
          ? '¿Aceptar a ${solicitud.nombre} en la comunidad ${widget.comunidad.nombre}?'
          : '¿Rechazar la solicitud de ${solicitud.nombre}?',
      confirmLabel: aceptar ? 'Aceptar' : 'Rechazar',
      isDanger: !aceptar,
      icon: aceptar ? Icons.check_circle_outline : Icons.cancel_outlined,
    );

    if (!confirmar) return;

    try {
      await _expedienteService.responderSolicitud(
        solicitud.id,
        aceptar: aceptar,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(aceptar
              ? 'Solicitud aceptada'
              : 'Solicitud rechazada'),
        ),
      );
      _cargarSolicitudes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.coralRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes • ${widget.comunidad.nombre}'),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Cargando solicitudes...')
          : _error != null
              ? ErrorState(
                  title: 'No se pudieron cargar las solicitudes',
                  message: _error,
                  onRetry: _cargarSolicitudes,
                )
              : _solicitudes.isEmpty
                  ? const EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'Sin solicitudes',
                      description:
                          'Cuando alguien solicite incorporarse aparecerá aquí',
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarSolicitudes,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _solicitudes.length,
                        itemBuilder: (context, index) {
                          final solicitud = _solicitudes[index];
                          return _SolicitudCard(
                            solicitud: solicitud,
                            onVerPerfil: () => _verPerfil(solicitud),
                            onAceptar: () =>
                                _responder(solicitud, aceptar: true),
                            onRechazar: () =>
                                _responder(solicitud, aceptar: false),
                          );
                        },
                      ),
                    ),
    );
  }

  void _verPerfil(SolicitudIncorporacion solicitud) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: Responsive.screenPadding(ctx).copyWith(
                top: AppSpacing.xl,
                bottom: AppSpacing.xxl,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(child: InitialsAvatar(name: solicitud.nombre, size: 72)),
              const SizedBox(height: AppSpacing.md),
              Text(
                solicitud.nombre,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Solicitud del ${AppDateUtils.formatDate(solicitud.fechaSolicitud)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (solicitud.informacionBasica != null) ...[
                const Text(
                  'Información básica',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    solicitud.informacionBasica!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ],
              if (solicitud.correo != null) ...[
                const SizedBox(height: AppSpacing.md),
                InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Correo',
                  value: solicitud.correo!,
                ),
              ],
              if (solicitud.telefono != null) ...[
                InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: solicitud.telefono!,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: DangerButton(
                      label: 'Rechazar',
                      icon: Icons.close,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _responder(solicitud, aceptar: false);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Aceptar',
                      icon: Icons.check,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _responder(solicitud, aceptar: true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  final SolicitudIncorporacion solicitud;
  final VoidCallback onVerPerfil;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _SolicitudCard({
    required this.solicitud,
    required this.onVerPerfil,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: solicitud.nombre, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDateUtils.formatDate(solicitud.fechaSolicitud),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                estado: solicitud.estado,
                customText: 'Pendiente',
                color: AppColors.mustardGold,
              ),
            ],
          ),
          if (solicitud.informacionBasica != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              solicitud.informacionBasica!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Ver perfil',
                  expanded: false,
                  onPressed: onVerPerfil,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Rechazar',
                color: AppColors.coralRed,
                onPressed: onRechazar,
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'Aceptar',
                color: AppColors.sageGreen,
                onPressed: onAceptar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
