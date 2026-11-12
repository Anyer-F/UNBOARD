import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/models/apadrinado.dart';
import '../../../shared/widgets/actividad_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/actividad_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/comunidad_service.dart';
import '../../../services/expediente_service.dart';
import '../actividades/actividad_detalle_screen.dart';
import '../actividades/crear_actividad_screen.dart';
import '../comunidades/solicitudes_screen.dart';
import '../expediente/expediente_actividad_screen.dart';
import '../expediente/expediente_detalle_screen.dart';
import '../historial/historial_screen.dart';

/// Inicio del Coordinador: resumen de su gestión, entregas por revisar
/// y accesos directos.
class CoordinadorHomeContent extends StatefulWidget {
  /// Cambia a la pestaña "Comunidades" del shell.
  final VoidCallback? onAbrirComunidades;

  /// Cambia a la pestaña "Actividades" del shell.
  final VoidCallback? onAbrirActividades;

  const CoordinadorHomeContent({super.key, this.onAbrirComunidades, this.onAbrirActividades});

  @override
  State<CoordinadorHomeContent> createState() => _CoordinadorHomeContentState();
}

class _CoordinadorHomeContentState extends State<CoordinadorHomeContent> {
  final _expedienteService = ExpedienteService();
  final _actividadService = ActividadService();
  final _comunidadService = ComunidadService();

  List<Apadrinado> _apadrinados = [];
  List<Actividad> _actividades = [];
  int _comunidades = 0;
  int _solicitudes = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = _actividades.isEmpty && _apadrinados.isEmpty;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        _expedienteService.apadrinados(),
        _actividadService.tablero(),
        _comunidadService.listar(),
        _comunidadService.solicitudesPendientes(),
      ]);
      if (!mounted) return;
      setState(() {
        _apadrinados = resultados[0] as List<Apadrinado>;
        _actividades = resultados[1] as List<Actividad>;
        _comunidades = (resultados[2] as List).length;
        _solicitudes = (resultados[3] as List).length;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargarDatos();
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
      comunidades: _comunidades,
      solicitudesPendientes: _solicitudes,
      apadrinados: _apadrinados,
      actividades: _actividades,
      onRefresh: _cargarDatos,
      onNuevaActividad: () => _abrir(const CrearActividadScreen()),
      onAbrirComunidades: widget.onAbrirComunidades,
      onAbrirActividades: widget.onAbrirActividades,
      onSolicitudes: () => _abrir(const SolicitudesScreen()),
      onExpedientesActividad: () => _abrir(const ExpedienteActividadScreen()),
      onHistorial: () => _abrir(const HistorialScreen(titulo: 'Historial de cambios')),
      onAbrirApadrinado: (apad) => _abrir(ExpedienteDetalleScreen(apadrinadoId: apad.id)),
      onAbrirActividad: (act) => _abrir(ActividadDetalleScreen(actividadId: act.id)),
    );
  }
}

/// Vista del inicio del Coordinador (sin estado ni red).
///
/// Una columna en teléfonos; en tablet/web el resumen y los accesos
/// quedan a la izquierda y los listados a la derecha.
class CoordinadorHomeView extends StatelessWidget {
  final String nombre;
  final int comunidades;
  final int solicitudesPendientes;
  final List<Apadrinado> apadrinados;

  /// Actividades del tablero (con su resumen de avance).
  final List<Actividad> actividades;
  final Future<void> Function() onRefresh;
  final VoidCallback? onNuevaActividad;
  final VoidCallback? onAbrirComunidades;
  final VoidCallback? onAbrirActividades;
  final VoidCallback? onSolicitudes;
  final VoidCallback? onExpedientesActividad;
  final VoidCallback? onHistorial;
  final void Function(Apadrinado)? onAbrirApadrinado;
  final void Function(Actividad)? onAbrirActividad;

  const CoordinadorHomeView({
    super.key,
    required this.nombre,
    this.comunidades = 0,
    this.solicitudesPendientes = 0,
    required this.apadrinados,
    required this.actividades,
    required this.onRefresh,
    this.onNuevaActividad,
    this.onAbrirComunidades,
    this.onAbrirActividades,
    this.onSolicitudes,
    this.onExpedientesActividad,
    this.onHistorial,
    this.onAbrirApadrinado,
    this.onAbrirActividad,
  });

  int get _porRevisar => actividades.fold(0, (s, a) => s + (a.resumen?.porRevisar ?? 0));

  List<Actividad> get _conEntregas =>
      actividades.where((a) => (a.resumen?.porRevisar ?? 0) > 0).toList();

  @override
  Widget build(BuildContext context) {
    final accesos = <Widget>[
      SecondaryButton(label: 'Nueva actividad', icon: Icons.add, onPressed: onNuevaActividad),
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
      SecondaryButton(label: 'Historial', icon: Icons.history, onPressed: onHistorial),
    ];
    final porRevisar = _conEntregas;

    return DashboardLayout(
      onRefresh: onRefresh,
      principal: [
        ProfileHeader(
          nombre: '¡Hola, $nombre!',
          nombreAvatar: nombre,
          correo: 'Coordinador de Proyecto • Huehuetenango',
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Mi resumen', subtitle: 'Visión general de tu gestión'),
        const SizedBox(height: AppSpacing.sm),
        MetricRow(
          children: [
            _MetricTile(
              label: 'Comunidades',
              value: '$comunidades',
              icon: Icons.location_city_outlined,
              color: AppColors.darkNavy,
            ),
            _MetricTile(
              label: 'Apadrinados',
              value: '${apadrinados.length}',
              icon: Icons.people_outlined,
              color: AppColors.tealCyan,
            ),
            _MetricTile(
              label: 'Actividades',
              value: '${actividades.length}',
              icon: Icons.assignment_outlined,
              color: AppColors.sageGreen,
            ),
            _MetricTile(
              label: 'Por revisar',
              value: '$_porRevisar',
              icon: Icons.rate_review_outlined,
              color: AppColors.mustardGold,
            ),
          ],
        ),
        if (solicitudesPendientes > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _AvisoSolicitudes(cantidad: solicitudesPendientes, onTap: onSolicitudes),
        ],
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 560 ? 2 : 1;
            final ancho = (constraints.maxWidth - AppSpacing.md * (columnas - 1)) / columnas;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [for (final a in accesos) SizedBox(width: ancho.floorToDouble(), child: a)],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      secundario: [
        SectionHeader(
          title: 'Entregas por revisar',
          subtitle: 'Actividades con entregas enviadas',
          action: onAbrirActividades == null
              ? null
              : TextButton(onPressed: onAbrirActividades, child: const Text('Ver tablero')),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (porRevisar.isEmpty)
          const EmptyState(
            icon: Icons.task_alt,
            title: 'Todo al día',
            description: 'No hay entregas esperando revisión',
          )
        else
          ...porRevisar.take(4).map(
                (act) => ActividadTableroCard(
                  actividad: act,
                  onTap: onAbrirActividad == null ? null : () => onAbrirActividad!(act),
                ),
              ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Actividades recientes', subtitle: 'Últimas actividades creadas'),
        const SizedBox(height: AppSpacing.sm),
        if (actividades.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No hay actividades',
            description: 'Crea tu primera actividad para comenzar',
          )
        else
          ...actividades.take(3).map(
                (act) => ActividadTableroCard(
                  actividad: act,
                  onTap: onAbrirActividad == null ? null : () => onAbrirActividad!(act),
                ),
              ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Apadrinados', subtitle: 'Acceso directo a los expedientes'),
        const SizedBox(height: AppSpacing.sm),
        if (apadrinados.isEmpty)
          const EmptyState(
            icon: Icons.people_outlined,
            title: 'Sin apadrinados',
            description: 'Los apadrinados de tus comunidades aparecerán aquí',
          )
        else
          ...apadrinados.take(3).map(
                (apad) => PersonCard(
                  nombre: apad.nombreCompleto.isNotEmpty ? apad.nombreCompleto : 'Apadrinado',
                  subtitle: apad.comunidadNombre ?? 'Sin asignar',
                  detail: apad.correo,
                  onTap: onAbrirApadrinado == null ? null : () => onAbrirApadrinado!(apad),
                ),
              ),
      ],
    );
  }
}

class _AvisoSolicitudes extends StatelessWidget {
  final int cantidad;
  final VoidCallback? onTap;

  const _AvisoSolicitudes({required this.cantidad, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.coralRed.withAlpha(18),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_1_outlined, color: AppColors.coralRed),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  cantidad == 1
                      ? '1 solicitud de incorporación pendiente'
                      : '$cantidad solicitudes de incorporación pendientes',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.coralRed),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.coralRed),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({required this.label, required this.value, required this.icon, required this.color});

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
            style: TextStyle(color: color.withAlpha(204), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
