import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/models/apadrinado.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/actividad_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/expediente_service.dart';
import '../actividades/actividad_detalle_screen.dart';
import '../actividades/crear_actividad_screen.dart';
import '../expediente/expediente_detalle_screen.dart';

/// Dashboard del Coordinador (especificación §22.1).
///
/// Resumen de apadrinados, actividades por revisar y
/// accesos directos. Tarjetas compactas.
class CoordinadorHomeContent extends StatefulWidget {
  const CoordinadorHomeContent({super.key});

  @override
  State<CoordinadorHomeContent> createState() =>
      _CoordinadorHomeContentState();
}

class _CoordinadorHomeContentState extends State<CoordinadorHomeContent> {
  final _expedienteService = ExpedienteService();
  final _actividadService = ActividadService();

  List<Apadrinado> _apadrinados = [];
  List<Actividad> _actividades = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.coordinadorId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apads = await _expedienteService
          .listarApadrinadosPorCoordinador(user!.coordinadorId!);
      final acts = await _actividadService
          .listarPorCoordinador(user.coordinadorId!);

      if (mounted) {
        setState(() {
          _apadrinados = apads;
          _actividades = acts;
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

  int get _porRevisar => _actividades
      .where((a) =>
          a.estado == 'ENTREGADA' || a.estado == 'EN_REVISION')
      .length;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    if (_isLoading) {
      return const LoadingState(message: 'Cargando tu panel...');
    }

    if (_error != null && _apadrinados.isEmpty && _actividades.isEmpty) {
      return ErrorState(
        title: 'No se pudieron cargar tus datos',
        message: _error,
        onRetry: _cargarDatos,
      );
    }

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
              ProfileHeader(
                nombre: '¡Hola, ${user?.nombre ?? "Coordinador"}!',
                correo: 'Coordinador de Proyecto • Huehuetenango',
              ),
              const SizedBox(height: AppSpacing.xl),

              // Resumen
              const SectionHeader(
                title: 'Mi resumen',
                subtitle: 'Visión general de tu gestión',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _MetricTile(
                    context: context,
                    label: 'Apadrinados',
                    value: '${_apadrinados.length}',
                    icon: Icons.people_outlined,
                    color: AppColors.tealCyan,
                  ),
                  _MetricTile(
                    context: context,
                    label: 'Por revisar',
                    value: '$_porRevisar',
                    icon: Icons.rate_review_outlined,
                    color: AppColors.mustardGold,
                  ),
                  _MetricTile(
                    context: context,
                    label: 'Actividades',
                    value: '${_actividades.length}',
                    icon: Icons.assignment_outlined,
                    color: AppColors.sageGreen,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Acceso rápido
              Responsive.isLarge(context)
                  ? Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Nueva actividad',
                            icon: Icons.add,
                            onPressed: () async {
                              final creada = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CrearActividadScreen(),
                                ),
                              );
                              if (creada == true) _cargarDatos();
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Mis comunidades',
                            icon: Icons.location_city_outlined,
                            onPressed: () {
                              Navigator.pushNamed(
                                  context, '/coordinador/comunidades');
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SecondaryButton(
                          label: 'Nueva actividad',
                          icon: Icons.add,
                          onPressed: () async {
                            final creada = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CrearActividadScreen(),
                              ),
                            );
                            if (creada == true) _cargarDatos();
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SecondaryButton(
                          label: 'Mis comunidades',
                          icon: Icons.location_city_outlined,
                          onPressed: () {
                            Navigator.pushNamed(
                                context, '/coordinador/comunidades');
                          },
                        ),
                      ],
                    ),
              const SizedBox(height: AppSpacing.xl),

              // Apadrinados recientes
              const SectionHeader(
                title: 'Apadrinados',
                subtitle: 'Acceso directo a los expedientes',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_apadrinados.isEmpty)
                const EmptyState(
                  icon: Icons.people_outlined,
                  title: 'Sin apadrinados',
                  description:
                      'Los apadrinados asignados aparecerán aquí',
                )
              else
                ..._apadrinados.take(3).map(
                      (apad) => PersonCard(
                        nombre: apad.nombre ?? 'Apadrinado',
                        subtitle: apad.comunidadNombre ?? 'Sin asignar',
                        detail: apad.correo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpedienteDetalleScreen(
                                apadrinadoId: apad.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: AppSpacing.xl),

              // Actividades recientes
              const SectionHeader(
                title: 'Actividades recientes',
                subtitle: 'Últimas actividades creadas',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_actividades.isEmpty)
                const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No hay actividades',
                  description: 'Crea tu primera actividad para comenzar',
                )
              else
                ..._actividades.take(3).map(
                      (act) => ActivityCard(
                        actividad: act,
                        onTap: () async {
                          final actualizado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActividadDetalleScreen(actividad: act),
                            ),
                          );
                          if (actualizado == true) _cargarDatos();
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final BuildContext context;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.context,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = Responsive.isLarge(context)
        ? (Responsive.maxContentWidth(context) - 32) / 3
        : (Responsive.width(context) - 48) / 2;

    return SizedBox(
      width: ancho,
      child: Container(
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
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
