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
import '../expediente/expediente_actividad_screen.dart';
import '../expediente/expediente_detalle_screen.dart';

/// Dashboard del Coordinador (especificación §22.1).
///
/// Resumen de apadrinados, actividades por revisar y
/// accesos directos. Tarjetas compactas.
class CoordinadorHomeContent extends StatefulWidget {
  /// Cambia a la pestaña "Comunidades" del shell.
  final VoidCallback? onAbrirComunidades;

  const CoordinadorHomeContent({super.key, this.onAbrirComunidades});

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

    return CoordinadorHomeView(
      nombre: user?.nombre ?? 'Coordinador',
      apadrinados: _apadrinados,
      actividades: _actividades,
      onRefresh: _cargarDatos,
      onNuevaActividad: () async {
        final creada = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CrearActividadScreen()),
        );
        if (creada == true) _cargarDatos();
      },
      onAbrirComunidades: widget.onAbrirComunidades,
      onExpedientesActividad: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpedienteActividadScreen()),
        );
      },
      onAbrirApadrinado: (apad) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpedienteDetalleScreen(apadrinadoId: apad.id),
          ),
        );
      },
      onAbrirActividad: (act) async {
        final actualizado = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActividadDetalleScreen(actividad: act)),
        );
        if (actualizado == true) _cargarDatos();
      },
    );
  }
}

/// Vista del dashboard del Coordinador (sin estado ni red).
///
/// Una columna en teléfonos; en tablet/web el resumen y los accesos
/// quedan a la izquierda y los listados a la derecha.
class CoordinadorHomeView extends StatelessWidget {
  final String nombre;
  final List<Apadrinado> apadrinados;
  final List<Actividad> actividades;
  final Future<void> Function() onRefresh;
  final VoidCallback? onNuevaActividad;
  final VoidCallback? onAbrirComunidades;
  final VoidCallback? onExpedientesActividad;
  final void Function(Apadrinado)? onAbrirApadrinado;
  final void Function(Actividad)? onAbrirActividad;

  const CoordinadorHomeView({
    super.key,
    required this.nombre,
    required this.apadrinados,
    required this.actividades,
    required this.onRefresh,
    this.onNuevaActividad,
    this.onAbrirComunidades,
    this.onExpedientesActividad,
    this.onAbrirApadrinado,
    this.onAbrirActividad,
  });

  int get _porRevisar => actividades
      .where((a) => a.estado == 'ENTREGADA' || a.estado == 'EN_REVISION')
      .length;

  @override
  Widget build(BuildContext context) {
    final accesos = <Widget>[
      SecondaryButton(
        label: 'Nueva actividad',
        icon: Icons.add,
        onPressed: onNuevaActividad,
      ),
      if (onAbrirComunidades != null)
        SecondaryButton(
          label: 'Mis comunidades',
          icon: Icons.location_city_outlined,
          onPressed: onAbrirComunidades,
        ),
      SecondaryButton(
        label: 'Expedientes por actividad',
        icon: Icons.folder_copy_outlined,
        onPressed: onExpedientesActividad,
      ),
    ];

    return DashboardLayout(
      onRefresh: onRefresh,
      principal: [
        ProfileHeader(
          nombre: '¡Hola, $nombre!',
          correo: 'Coordinador de Proyecto • Huehuetenango',
        ),
        const SizedBox(height: AppSpacing.xl),

        // Resumen
        const SectionHeader(
          title: 'Mi resumen',
          subtitle: 'Visión general de tu gestión',
        ),
        const SizedBox(height: AppSpacing.sm),
        MetricRow(
          children: [
            _MetricTile(
              label: 'Apadrinados',
              value: '${apadrinados.length}',
              icon: Icons.people_outlined,
              color: AppColors.tealCyan,
            ),
            _MetricTile(
              label: 'Por revisar',
              value: '$_porRevisar',
              icon: Icons.rate_review_outlined,
              color: AppColors.mustardGold,
            ),
            _MetricTile(
              label: 'Actividades',
              value: '${actividades.length}',
              icon: Icons.assignment_outlined,
              color: AppColors.sageGreen,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Acceso rápido: un botón por fila en teléfono, en fila en pantallas anchas
        LayoutBuilder(
          builder: (context, constraints) {
            final enFila = constraints.maxWidth >= 560;
            if (!enFila) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < accesos.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    accesos[i],
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < accesos.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: accesos[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      secundario: [
        // Apadrinados recientes
        const SectionHeader(
          title: 'Apadrinados',
          subtitle: 'Acceso directo a los expedientes',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (apadrinados.isEmpty)
          const EmptyState(
            icon: Icons.people_outlined,
            title: 'Sin apadrinados',
            description: 'Los apadrinados asignados aparecerán aquí',
          )
        else
          ...apadrinados.take(3).map(
                (apad) => PersonCard(
                  nombre: apad.nombre ?? 'Apadrinado',
                  subtitle: apad.comunidadNombre ?? 'Sin asignar',
                  detail: apad.correo,
                  onTap: onAbrirApadrinado == null
                      ? null
                      : () => onAbrirApadrinado!(apad),
                ),
              ),
        const SizedBox(height: AppSpacing.xl),

        // Actividades recientes
        const SectionHeader(
          title: 'Actividades recientes',
          subtitle: 'Últimas actividades creadas',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (actividades.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No hay actividades',
            description: 'Crea tu primera actividad para comenzar',
          )
        else
          ...actividades.take(3).map(
                (act) => ActivityCard(
                  actividad: act,
                  onTap: onAbrirActividad == null
                      ? null
                      : () => onAbrirActividad!(act),
                ),
              ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
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
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withAlpha(204),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
