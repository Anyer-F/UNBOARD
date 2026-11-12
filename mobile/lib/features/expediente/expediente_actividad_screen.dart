import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../services/actividad_service.dart';
import '../../services/comunidad_service.dart';
import '../../services/expediente_service.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/comunidad.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/states.dart';
import '../actividades/actividad_detalle_screen.dart';

/// Expedientes por actividad: PDF y carpeta ZIP de una tarea con las
/// entregas aprobadas de los apadrinados de la comunidad.
class ExpedienteActividadScreen extends StatefulWidget {
  const ExpedienteActividadScreen({super.key});

  @override
  State<ExpedienteActividadScreen> createState() => _ExpedienteActividadScreenState();
}

class _ExpedienteActividadScreenState extends State<ExpedienteActividadScreen> {
  final _actividadService = ActividadService();

  List<Comunidad> _comunidades = [];
  List<Actividad> _tareas = [];
  int? _comunidadId;
  bool _isLoading = true;
  String? _error;
  final Map<int, String> _exportando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = _tareas.isEmpty;
      _error = null;
    });
    try {
      final r = await Future.wait([
        ComunidadService().listar(),
        _actividadService.tablero(comunidadId: _comunidadId, tipo: TipoActividad.tarea),
      ]);
      if (mounted) {
        setState(() {
          _comunidades = r[0] as List<Comunidad>;
          _tareas = r[1] as List<Actividad>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Future<void> _exportar(Actividad a, bool pdf) async {
    setState(() => _exportando[a.id] = pdf ? 'pdf' : 'zip');
    try {
      final e = pdf ? await _actividadService.exportarPdf(a.id) : await _actividadService.exportarZip(a.id);
      final msg = await ExpedienteService().descargarYAbrir(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeDeError(e)), backgroundColor: AppColors.coralRed),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando.remove(a.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final conAprobadas = _tareas.where((a) => (a.resumen?.aprobados ?? 0) > 0).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Expedientes por actividad')),
      body: _isLoading
          ? const LoadingState(message: 'Cargando actividades...')
          : _error != null && _tareas.isEmpty
              ? ErrorState(title: 'No se pudieron cargar las actividades', message: _error, onRetry: _cargar)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    children: [
                      ResponsiveContent(
                        maxWidth: 900,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Genera el expediente PDF o la carpeta ZIP de una tarea. Solo se incluyen las '
                              'entregas aprobadas, por eso la opción se habilita cuando hay al menos una.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            if (_comunidades.length > 1) ...[
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  FilterChipWidget(
                                    label: 'Todas',
                                    selected: _comunidadId == null,
                                    onSelected: () {
                                      setState(() => _comunidadId = null);
                                      _cargar();
                                    },
                                  ),
                                  for (final c in _comunidades)
                                    FilterChipWidget(
                                      label: c.nombre,
                                      selected: _comunidadId == c.id,
                                      onSelected: () {
                                        setState(() => _comunidadId = c.id);
                                        _cargar();
                                      },
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Text('${_tareas.length} tareas · $conAprobadas con entregas aprobadas',
                                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_tareas.isEmpty)
                        const EmptyState(icon: Icons.assignment_outlined, title: 'Sin tareas')
                      else
                        ResponsiveContent(
                          maxWidth: 900,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final a in _tareas)
                                ActividadTableroCard(
                                  actividad: a,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ActividadDetalleScreen(actividadId: a.id)),
                                  ),
                                  trailing: _Botones(
                                    habilitado: (a.resumen?.aprobados ?? 0) > 0,
                                    exportando: _exportando[a.id],
                                    onPdf: () => _exportar(a, true),
                                    onZip: () => _exportar(a, false),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _Botones extends StatelessWidget {
  final bool habilitado;
  final String? exportando;
  final VoidCallback onPdf;
  final VoidCallback onZip;

  const _Botones({required this.habilitado, required this.exportando, required this.onPdf, required this.onZip});

  @override
  Widget build(BuildContext context) {
    if (exportando != null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final ayuda = habilitado ? null : 'Requiere al menos una entrega aprobada';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: ayuda ?? 'Expediente PDF',
          icon: Icon(Icons.picture_as_pdf_outlined, color: habilitado ? AppColors.coralRed : AppColors.textTertiary),
          onPressed: habilitado ? onPdf : null,
        ),
        IconButton(
          tooltip: ayuda ?? 'Carpeta ZIP',
          icon: Icon(Icons.folder_zip_outlined, color: habilitado ? AppColors.darkNavy : AppColors.textTertiary),
          onPressed: habilitado ? onZip : null,
        ),
      ],
    );
  }
}
