import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/apadrinado.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/models/comunidad.dart';
import '../../../shared/models/solicitud_incorporacion.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/auth_service.dart';
import '../../../services/expediente_service.dart';
import '../../../services/actividad_service.dart';
import '../actividades/actividad_detalle_screen.dart';
import '../actividades/crear_actividad_screen.dart';
import '../expediente/expediente_detalle_screen.dart';
import 'solicitudes_screen.dart';

/// Detalle de comunidad (especificación §23).
///
/// Muestra el código de comunidad y dos pestañas:
/// Personas (apadrinados) y Actividades asignadas.
class ComunidadDetalleScreen extends StatefulWidget {
  final Comunidad comunidad;

  const ComunidadDetalleScreen({
    super.key,
    required this.comunidad,
  });

  @override
  State<ComunidadDetalleScreen> createState() =>
      _ComunidadDetalleScreenState();
}

class _ComunidadDetalleScreenState
    extends State<ComunidadDetalleScreen>
    with SingleTickerProviderStateMixin {
  final _expedienteService = ExpedienteService();
  final _actividadService = ActividadService();

  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  List<Apadrinado> _apadrinados = [];
  List<Actividad> _actividades = [];
  List<SolicitudIncorporacion> _solicitudes = [];
  String _codigo = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      final apadrinados = await _expedienteService
          .listarApadrinadosPorCoordinador(user!.coordinadorId!);
      final actividades = await _actividadService
          .listarPorCoordinador(user.coordinadorId!);
      final solicitudes =
          await _expedienteService.listarSolicitudes(widget.comunidad.id);
      final codigo =
          await _expedienteService.obtenerCodigoComunidad(
        widget.comunidad.id,
      );

      if (mounted) {
        setState(() {
          _apadrinados = apadrinados
              .where((a) => a.comunidadId == widget.comunidad.id)
              .toList();
          _actividades = actividades
              .where((a) =>
                  a.apadrinadoId != null &&
                  _apadrinados
                      .any((ap) => ap.id == a.apadrinadoId))
              .toList();
          _solicitudes = solicitudes
              .where((s) => s.isPendiente)
              .toList();
          _codigo = codigo;
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

  int _pendientesEnComunidad() {
    return _actividades
        .where((a) =>
            a.estado == 'PENDIENTE' ||
            a.estado == 'EN_PROCESO' ||
            a.estado == 'ENTREGADA' ||
            a.estado == 'EN_REVISION')
        .length;
  }

  Future<void> _crearActividad() async {
    final creada = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearActividadScreen(
          comunidad: widget.comunidad,
        ),
      ),
    );
    if (creada == true) _cargarDatos();
  }

  Future<void> _editarActividad(Actividad act) async {
    final actualizado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearActividadScreen(
          actividadParaEditar: act,
        ),
      ),
    );
    if (actualizado == true) _cargarDatos();
  }

  Future<void> _eliminarActividad(Actividad act) async {
    final confirmar = await showConfirmationDialog(
      context,
      title: 'Eliminar actividad',
      message:
          '¿Eliminar "${act.titulo}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDanger: true,
      icon: Icons.delete_outline,
    );
    if (!confirmar || !mounted) return;

    try {
      await _actividadService.eliminar(act.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Actividad "${act.titulo}" eliminada'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error al eliminar: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.comunidad.nombre),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Cargando comunidad...')
          : _error != null && _apadrinados.isEmpty && _actividades.isEmpty
              ? ErrorState(
                  title: 'No se pudo cargar la comunidad',
                  message: _error,
                  onRetry: _cargarDatos,
                )
              : Column(
                  children: [
                    // Encabezado: código y resumen
                    AppCard(
                      margin: const EdgeInsets.all(AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          const Text(
                            'Código de comunidad',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _codigo.isNotEmpty ? _codigo : '---',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkNavy,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                icon: const Icon(
                                  Icons.content_copy_outlined,
                                  color: AppColors.tealCyan,
                                ),
                                tooltip: 'Copiar código',
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Código copiado al portapapeles'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              _Stat(
                                value: '${_apadrinados.length}',
                                label: 'Apadrinados',
                              ),
                              _Stat(
                                value: '${_pendientesEnComunidad()}',
                                label: 'Actividades pendientes',
                              ),
                              _Stat(
                                value: '${_solicitudes.length}',
                                label: 'Solicitudes',
                              ),
                            ],
                          ),
                          if (_solicitudes.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SolicitudesScreen(
                                      comunidad: widget.comunidad,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.how_to_reg_outlined,
                                size: 18,
                                color: AppColors.coralRed,
                              ),
                              label: Text(
                                'Revisar ${_solicitudes.length} solicitud(es) pendiente(s)',
                                style: const TextStyle(
                                    color: AppColors.coralRed),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Pestañas: Personas · Actividades
                    TabBar(
                      controller: _tabController,
                      dividerColor: AppColors.borderLight,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Personas'),
                        Tab(text: 'Actividades'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabPersonas(),
                          _buildTabActividades(),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.darkNavy,
        onPressed: _crearActividad,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Actividad',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTabPersonas() {
    if (_apadrinados.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outlined,
        title: 'Sin apadrinados',
        description: 'Los apadrinados de esta comunidad aparecerán aquí',
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _apadrinados.length,
        itemBuilder: (context, index) {
          final apad = _apadrinados[index];
          return PersonCard(
            nombre: apad.nombre ?? 'Apadrinado',
            subtitle: apad.comunidadNombre ?? widget.comunidad.nombre,
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
          );
        },
      ),
    );
  }

  Widget _buildTabActividades() {
    if (_actividades.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Sin actividades',
        description:
            'Las actividades asignadas a esta comunidad aparecerán aquí',
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _actividades.length,
        itemBuilder: (context, index) {
          final act = _actividades[index];
          return ActivityCard(
            actividad: act,
            onTap: () async {
              final actualizado = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActividadDetalleScreen(actividad: act),
                ),
              );
              if (actualizado == true) _cargarDatos();
            },
            onEditar: () => _editarActividad(act),
            onEliminar: () => _eliminarActividad(act),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
