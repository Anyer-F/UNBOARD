import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/actividad.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/actividad_service.dart';
import '../../../services/auth_service.dart';
import 'actividad_entrega_screen.dart';

/// Lista de actividades del Apadrinado (especificación §16).
///
/// Flujo: Lista → Detalle → Entrega → Revisión.
/// Con filtros: Todos, Pendientes, En revisión, Completadas.
class ApadrinadoActividadesContent extends StatefulWidget {
  const ApadrinadoActividadesContent({super.key});

  @override
  State<ApadrinadoActividadesContent> createState() =>
      _ApadrinadoActividadesContentState();
}

class _ApadrinadoActividadesContentState
    extends State<ApadrinadoActividadesContent> {  final _actividadService = ActividadService();

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
    if (user?.apadrinadoId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lista =
          await _actividadService.listarPorApadrinado(user!.apadrinadoId!);
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
            .where((a) =>
                a.estado == 'PENDIENTE' || a.estado == 'EN_PROCESO')
            .toList();
      case 'EN_REVISION':
        return _actividades
            .where((a) =>
                a.estado == 'ENTREGADA' || a.estado == 'EN_REVISION')
            .toList();
      case 'COMPLETADAS':
        return _actividades
            .where((a) =>
                a.estado == 'APROBADA' || a.estado == 'CORRECCION_SOLICITADA')
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
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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
                  onSelected: () {
                    setState(() => _filtro = filtro);
                  },
                ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: _filtradas.isEmpty
              ? EmptyState(
                  icon: Icons.assignment_outlined,
                  title: _actividades.isEmpty
                      ? 'No hay actividades'
                      : 'Sin resultados',
                  description: _actividades.isEmpty
                      ? 'Cuando te asignen actividades aparecerán aquí'
                      : 'No hay actividades con este filtro',
                  action: _actividades.isEmpty
                      ? null
                      : SecondaryButton(
                          label: 'Ver todas',
                          expanded: false,
                          onPressed: () => setState(() => _filtro = 'TODOS'),
                        ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarActividades,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    itemCount: _filtradas.length,
                    itemBuilder: (context, index) {
                      final act = _filtradas[index];
                      return ActivityCard(
                        actividad: act,
                        onTap: () async {
                          final enviada = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActividadEntregaScreen(actividad: act),
                            ),
                          );
                          if (enviada == true) _cargarActividades();
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
