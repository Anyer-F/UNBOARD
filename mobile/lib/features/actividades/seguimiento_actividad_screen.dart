import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/models/apadrinado.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../core/network/api_client.dart';

/// Entrega de un apadrinado para una actividad.
class EntregaApadrinado {
  final Apadrinado apadrinado;
  final String estado;
  final String? fechaEnvio;

  EntregaApadrinado({
    required this.apadrinado,
    required this.estado,
    this.fechaEnvio,
  });

  factory EntregaApadrinado.fromJson(Map<String, dynamic> json) {
    return EntregaApadrinado(
      apadrinado: Apadrinado.fromJson(
        json['apadrinado'] ?? {'id': json['apadrinadoId'], 'nombre': json['apadrinadoNombre']},
      ),
      estado: json['estado'] ?? 'PENDIENTE',
      fechaEnvio: json['fechaEnvio'],
    );
  }
}

/// Seguimiento de actividad (especificación §27).
///
/// Resumen con barras de progreso, chips y lista
/// de participantes con su estado de entrega.
class SeguimientoActividadScreen extends StatefulWidget {
  final Actividad actividad;

  const SeguimientoActividadScreen({
    super.key,
    required this.actividad,
  });

  @override
  State<SeguimientoActividadScreen> createState() =>
      _SeguimientoActividadScreenState();
}

class _SeguimientoActividadScreenState
    extends State<SeguimientoActividadScreen> {
  final _api = ApiService();

  List<EntregaApadrinado> _entregas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSeguimiento();
  }

  Future<void> _cargarSeguimiento() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Endpoint de entregas por actividad.
      // Mientras no esté disponible se muestra el estado de error
      // con opción de reintentar (especificación §13).
      final response = await _api
          .get('/api/actividades/${widget.actividad.id}/entregas');
      final entregas = <EntregaApadrinado>[];
      if (response is List) {
        entregas.addAll(
          response.map((e) => EntregaApadrinado.fromJson(e)),
        );
      }

      if (mounted) {
        setState(() {
          _entregas = entregas;
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

  int get _total => _entregas.length;

  int get _completadas => _entregas
      .where((e) => e.estado.toUpperCase() == 'APROBADA')
      .length;

  int get _enRevision => _entregas
      .where((e) =>
          e.estado.toUpperCase() == 'EN_REVISION' ||
          e.estado.toUpperCase() == 'ENTREGADA')
      .length;

  int get _pendientes => _total - _completadas - _enRevision;

  double get _progreso => _total == 0 ? 0 : _completadas / _total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento'),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Cargando seguimiento...')
          : _error != null
              ? ErrorState(
                  title: 'No se pudo cargar el seguimiento',
                  message: _error,
                  onRetry: _cargarSeguimiento,
                )
              : RefreshIndicator(
                  onRefresh: _cargarSeguimiento,
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
                          // Actividad
                          ProfileHeader(
                            nombre: widget.actividad.titulo,
                            correo: AppDateUtils.formatDate(
                                widget.actividad.fechaLimite),
                            comunidad: widget.actividad.apadrinadoNombre,
                            rol: 'Actividad',
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Resumen
                          const SectionHeader(
                            title: 'Resumen de entregas',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppCard(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _ResumenStat(
                                      value: '$_total',
                                      label: 'Apadrinados',
                                      color: AppColors.darkNavy,
                                    ),
                                    _ResumenStat(
                                      value: '$_completadas',
                                      label: 'Completaron',
                                      color: AppColors.sageGreen,
                                    ),
                                    _ResumenStat(
                                      value: '$_enRevision',
                                      label: 'En revisión',
                                      color: AppColors.tealCyan,
                                    ),
                                    _ResumenStat(
                                      value: '$_pendientes',
                                      label: 'Pendientes',
                                      color: AppColors.mustardGold,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                LinearProgressIndicator(
                                  value: _progreso,
                                  minHeight: 8,
                                  backgroundColor: AppColors.borderLight,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    AppColors.sageGreen,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '${(_progreso * 100).round()}% completado',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Participantes
                          const SectionHeader(
                            title: 'Participantes',
                            subtitle: 'Estado de cada entrega',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_entregas.isEmpty)
                            const EmptyState(
                              icon: Icons.people_outline,
                              title: 'Sin participantes',
                              description:
                                  'Las entregas de los apadrinados aparecerán aquí',
                            )
                          else
                            ..._entregas.map(
                              (entrega) => AppCard(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Row(
                                  children: [
                                    InitialsAvatar(
                                      name:
                                          entrega.apadrinado.nombre ?? 'A',
                                      size: 44,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entrega.apadrinado.nombre ??
                                                'Apadrinado',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          if (entrega.fechaEnvio !=
                                                  null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              AppDateUtils.formatDateTime(
                                                  entrega.fechaEnvio),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    StatusChip(
                                      estado: entrega.estado,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _ResumenStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _ResumenStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
