import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/apadrinado.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/models/comunidad.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/actividad_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/expediente_service.dart';
import 'comunidad_detalle_screen.dart';

/// Lista de comunidades del Coordinador (especificación §23).
///
/// Cada comunidad se muestra como tarjeta con
/// número de apadrinados y actividades pendientes.
class ComunidadesScreen extends StatefulWidget {
  const ComunidadesScreen({super.key});

  @override
  State<ComunidadesScreen> createState() => _ComunidadesScreenState();
}

class _ComunidadesScreenState extends State<ComunidadesScreen> {
  final _expedienteService = ExpedienteService();

  List<Comunidad> _comunidades = [];
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
      final comunidades = await _expedienteService.listarComunidades();
      final apadrinados =
          await _expedienteService.listarApadrinadosPorCoordinador(
        user!.coordinadorId!,
      );
      final actividades = await ActividadService()
          .listarPorCoordinador(user.coordinadorId!);

      if (mounted) {
        setState(() {
          _comunidades = comunidades;
          _apadrinados = apadrinados;
          _actividades = actividades;
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

  int _apadrinadosEn(int? comunidadId) => _apadrinados
      .where((a) => a.comunidadId == comunidadId)
      .length;

  int _pendientesEn(int? comunidadId) {
    final ids = _apadrinados
        .where((a) => a.comunidadId == comunidadId)
        .map((a) => a.id)
        .toSet();
    return _actividades
        .where((a) =>
            a.apadrinadoId != null &&
            ids.contains(a.apadrinadoId) &&
            (a.estado == 'PENDIENTE' ||
                a.estado == 'EN_PROCESO' ||
                a.estado == 'ENTREGADA' ||
                a.estado == 'EN_REVISION'))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingState(message: 'Cargando comunidades...');
    }

    if (_error != null && _comunidades.isEmpty) {
      return ErrorState(
        title: 'No se pudieron cargar las comunidades',
        message: _error,
        onRetry: _cargarDatos,
      );
    }

    if (_comunidades.isEmpty) {
      return const EmptyState(
        icon: Icons.location_city_outlined,
        title: 'Sin comunidades',
        description: 'Las comunidades asignadas aparecerán aquí',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _comunidades.length,
        itemBuilder: (context, index) {
          final comunidad = _comunidades[index];
          return CommunityCard(
            comunidad: comunidad,
            apadrinadosCount: _apadrinadosEn(comunidad.id),
            actividadesPendientes: _pendientesEn(comunidad.id),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComunidadDetalleScreen(
                    comunidad: comunidad,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
