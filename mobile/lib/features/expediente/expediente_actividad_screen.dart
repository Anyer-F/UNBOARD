import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/file_export.dart';
import '../../core/utils/responsive.dart';
import '../../services/expediente_service.dart';
import '../../shared/models/actividad_comunidad_resumen.dart';
import '../../shared/models/comunidad.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/states.dart';

/// Expedientes por actividad (Coordinador).
///
/// Genera, para una actividad de una comunidad, un expediente PDF o
/// ZIP con el estado y las evidencias de cada apadrinado. Por defecto
/// incluye solo las entregas aprobadas.
class ExpedienteActividadScreen extends StatefulWidget {
  const ExpedienteActividadScreen({super.key});

  @override
  State<ExpedienteActividadScreen> createState() =>
      _ExpedienteActividadScreenState();
}

class _ExpedienteActividadScreenState extends State<ExpedienteActividadScreen> {
  final _expedienteService = ExpedienteService();

  List<Comunidad> _comunidades = [];
  Comunidad? _comunidad;
  List<ActividadComunidadResumen> _actividades = [];
  bool _soloAprobadas = true;

  bool _cargandoComunidades = true;
  bool _cargandoActividades = false;
  String? _error;

  /// Descarga en curso: `{actividadId}-pdf` o `{actividadId}-zip`.
  String? _descargando;

  @override
  void initState() {
    super.initState();
    _cargarComunidades();
  }

  Future<void> _cargarComunidades() async {
    setState(() {
      _cargandoComunidades = true;
      _error = null;
    });
    try {
      final comunidades = await _expedienteService.listarMisComunidades();
      if (!mounted) return;
      setState(() {
        _comunidades = comunidades;
        _cargandoComunidades = false;
      });
      if (comunidades.length == 1) _seleccionarComunidad(comunidades.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoComunidades = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _seleccionarComunidad(Comunidad comunidad) async {
    setState(() {
      _comunidad = comunidad;
      _actividades = [];
      _cargandoActividades = true;
      _error = null;
    });
    try {
      final actividades =
          await _expedienteService.listarActividadesDeComunidad(comunidad.id);
      if (!mounted || _comunidad?.id != comunidad.id) return;
      setState(() {
        _actividades = actividades;
        _cargandoActividades = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoActividades = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _descargar(ActividadComunidadResumen act, {required bool zip}) async {
    final comunidad = _comunidad;
    if (comunidad == null) return;
    setState(() => _descargando = '${act.actividadId}-${zip ? 'zip' : 'pdf'}');

    try {
      final bytes = await _expedienteService.descargarExpedienteActividad(
        act.actividadId,
        comunidadId: comunidad.id,
        soloAprobadas: _soloAprobadas,
        zip: zip,
      );
      final mensaje = await guardarYAbrirArchivo(
        bytes,
        nombre: 'Expediente_Actividad_${act.actividadId}.${zip ? 'zip' : 'pdf'}',
        mimeType: zip ? 'application/zip' : 'application/pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: AppColors.sageGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar el expediente: '
              '${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.coralRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _descargando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expedientes por actividad')),
      body: _cargandoComunidades
          ? const LoadingState(message: 'Cargando comunidades...')
          : _comunidades.isEmpty
              ? (_error != null
                  ? ErrorState(
                      title: 'No se pudieron cargar tus comunidades',
                      message: _error,
                      onRetry: _cargarComunidades,
                    )
                  : const EmptyState(
                      icon: Icons.location_city_outlined,
                      title: 'Sin comunidades',
                      description:
                          'Necesitas tener comunidades asignadas para generar expedientes.',
                    ))
              : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_comunidad != null) await _seleccionarComunidad(_comunidad!);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          ResponsiveContent(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  value: _comunidad?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Comunidad',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: [
                    for (final c in _comunidades)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    _seleccionarComunidad(_comunidades.firstWhere((c) => c.id == id));
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Solo entregas aprobadas'),
                  subtitle: Text(_soloAprobadas
                      ? 'Incluye únicamente a los apadrinados con la actividad aprobada'
                      : 'Incluye a todos los apadrinados de la comunidad'),
                  value: _soloAprobadas,
                  onChanged: (v) => setState(() => _soloAprobadas = v),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._buildActividades(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActividades() {
    if (_comunidad == null) {
      return const [
        EmptyState(
          icon: Icons.touch_app_outlined,
          title: 'Elige una comunidad',
          description: 'Verás sus actividades para generar el expediente.',
        ),
      ];
    }
    if (_cargandoActividades) {
      return const [LoadingState(message: 'Cargando actividades...')];
    }
    if (_error != null) {
      return [
        ErrorState(
          title: 'No se pudieron cargar las actividades',
          message: _error,
          onRetry: () => _seleccionarComunidad(_comunidad!),
        ),
      ];
    }
    if (_actividades.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.assignment_outlined,
          title: 'Sin actividades',
          description: 'Esta comunidad todavía no tiene actividades asignadas.',
        ),
      ];
    }
    return [
      for (final act in _actividades)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ActividadExpedienteCard(
            actividad: act,
            soloAprobadas: _soloAprobadas,
            descargando: _descargando,
            onDescargar: (zip) => _descargar(act, zip: zip),
          ),
        ),
    ];
  }
}

class _ActividadExpedienteCard extends StatelessWidget {
  final ActividadComunidadResumen actividad;
  final bool soloAprobadas;
  final String? descargando;
  final void Function(bool zip) onDescargar;

  const _ActividadExpedienteCard({
    required this.actividad,
    required this.soloAprobadas,
    required this.descargando,
    required this.onDescargar,
  });

  @override
  Widget build(BuildContext context) {
    final total = actividad.totalAsignadas;
    final aprobadas = actividad.totalAprobadas;
    final sinAprobadas = soloAprobadas && aprobadas == 0;
    final ocupado = descargando != null;

    Widget boton({required bool zip}) {
      final cargando = descargando == '${actividad.actividadId}-${zip ? 'zip' : 'pdf'}';
      final icono = cargando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(zip ? Icons.archive_outlined : Icons.picture_as_pdf_outlined, size: 18);
      final onPressed = (ocupado || sinAprobadas) ? null : () => onDescargar(zip);
      return zip
          ? OutlinedButton.icon(onPressed: onPressed, icon: icono, label: const Text('ZIP'))
          : FilledButton.icon(onPressed: onPressed, icon: icono, label: const Text('PDF'));
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            actividad.titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Dato(
                icon: Icons.event_outlined,
                texto: 'Creada ${AppDateUtils.formatShort(actividad.fechaCreacion)}',
              ),
              if (actividad.fechaLimite != null)
                _Dato(
                  icon: Icons.flag_outlined,
                  texto: 'Límite ${AppDateUtils.formatShort(actividad.fechaLimite)}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ProgressBar(
            value: total == 0 ? 0 : aprobadas / total,
            label: 'Aprobadas: $aprobadas de $total',
            color: AppColors.sageGreen,
          ),
          if (sinAprobadas) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Aún no hay entregas aprobadas para esta actividad.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [boton(zip: true), boton(zip: false)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _Dato({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
