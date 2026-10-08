import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/actividad_service.dart';
import '../../../services/auth_service.dart';
import 'actividad_detalle_screen.dart';
import 'crear_actividad_screen.dart';

/// Lista de actividades del Coordinador (especificación §22.11).
///
/// Con filtros y acceso al seguimiento de cada actividad.
class CoordinadorActividadesContent extends StatefulWidget {
  const CoordinadorActividadesContent({super.key});

  @override
  State<CoordinadorActividadesContent> createState() =>
      _CoordinadorActividadesContentState();
}

class _CoordinadorActividadesContentState
    extends State<CoordinadorActividadesContent> {
  final _actividadService = ActividadService();

  List<Actividad> _actividades = [];
  bool _isLoading = true;
  String? _error;
  String _filtro = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarActividades();
  }

  Future<void> _cargarActividades() async {
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
      final lista =
          await _actividadService.listarPorCoordinador(user!.coordinadorId!);
      if (mounted) {
        setState(() {
          _actividades = lista;
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

  List<Actividad> get _filtradas {
    switch (_filtro) {
      case 'PENDIENTES':
        return _actividades
            .where((a) => a.estado == 'PENDIENTE' || a.estado == 'EN_PROCESO')
            .toList();
      case 'EN_REVISION':
        return _actividades
            .where((a) => a.estado == 'ENTREGADA' || a.estado == 'EN_REVISION')
            .toList();
      case 'COMPLETADAS':
        return _actividades
            .where((a) => a.estado == 'APROBADA')
            .toList();
      default:
        return _actividades;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingState(message: 'Cargando actividades...');
    }

    if (_error != null && _actividades.isEmpty) {
      return ErrorState(
        title: 'No se pudieron cargar las actividades',
        message: _error,
        onRetry: _cargarActividades,
      );
    }

    return Column(
      children: [
        // Filtros
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final filtro in const [
                'TODOS',
                'PENDIENTES',
                'EN_REVISION',
                'COMPLETADAS'
              ])
                FilterChipWidget(
                  label: filtro == 'TODOS'
                      ? 'Todos'
                      : filtro == 'PENDIENTES'
                          ? 'Pendientes'
                          : filtro == 'EN_REVISION'
                              ? 'En revisión'
                              : 'Completadas',
                  selected: _filtro == filtro,
                  onSelected: () => setState(() => _filtro = filtro),
                ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: _actividades.isEmpty
              ? EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No hay actividades',
                  description: 'Crea tu primera actividad para comenzar',
                  action: SecondaryButton(
                    label: 'Crear actividad',
                    icon: Icons.add,
                    expanded: false,
                    onPressed: _crearActividad,
                  ),
                )
              : _filtradas.isEmpty
                  ? EmptyState(
                      icon: Icons.filter_list_off,
                      title: 'Sin resultados',
                      description: 'No hay actividades con este filtro',
                      action: SecondaryButton(
                        label: 'Ver todas',
                        expanded: false,
                        onPressed: () => setState(() => _filtro = 'TODOS'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarActividades,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filtradas.length,
                        itemBuilder: (context, index) {
                          final act = _filtradas[index];
                          return ActivityCard(
                            actividad: act,
                            onTap: () async {
                              final actualizado = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ActividadDetalleScreen(actividad: act),
                                ),
                              );
                              if (actualizado == true) _cargarActividades();
                            },
                            onEditar: () => _editarActividad(act),
                            onEliminar: () => _eliminarActividad(act),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _crearActividad() async {
    final creada = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CrearActividadScreen()),
    );
    if (creada == true) _cargarActividades();
  }

  Future<void> _editarActividad(Actividad act) async {
    final actualizado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearActividadScreen(actividadParaEditar: act),
      ),
    );
    if (actualizado == true) _cargarActividades();
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
        _cargarActividades();
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
}
