import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/actividad_service.dart';
import '../../services/comunidad_service.dart';
import '../../services/expediente_service.dart';
import '../../shared/models/historial_actividad.dart';
import '../../shared/widgets/states.dart';

/// Historial de cambios (trazabilidad): de una comunidad, de un
/// apadrinado, de una actividad o de todas las comunidades del coordinador.
class HistorialScreen extends StatefulWidget {
  final int? comunidadId;
  final int? apadrinadoId;
  final int? actividadId;
  final String titulo;

  const HistorialScreen({
    super.key,
    this.comunidadId,
    this.apadrinadoId,
    this.actividadId,
    this.titulo = 'Historial',
  });

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<HistorialActividad> _registros = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = _registros.isEmpty;
      _error = null;
    });
    try {
      final List<HistorialActividad> lista;
      if (widget.actividadId != null) {
        lista = await ActividadService().historial(widget.actividadId!);
      } else if (widget.apadrinadoId != null) {
        lista = await ExpedienteService().historial(widget.apadrinadoId!);
      } else if (widget.comunidadId != null) {
        lista = await ComunidadService().historial(widget.comunidadId!);
      } else {
        lista = await ExpedienteService().historialGeneral();
      }
      if (mounted) {
        setState(() {
          _registros = lista;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: _isLoading
          ? const LoadingState(message: 'Cargando historial...')
          : _error != null && _registros.isEmpty
              ? ErrorState(title: 'No se pudo cargar el historial', message: _error, onRetry: _cargar)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: HistorialLista(registros: _registros, conFiltro: true),
                ),
    );
  }
}

/// Línea de tiempo de registros del historial, con filtro de texto
/// opcional. Ocupa el espacio disponible y hace scroll propio.
class HistorialLista extends StatefulWidget {
  final List<HistorialActividad> registros;
  final bool conFiltro;

  const HistorialLista({super.key, required this.registros, this.conFiltro = true});

  @override
  State<HistorialLista> createState() => _HistorialListaState();
}

class _HistorialListaState extends State<HistorialLista> {
  final _filtro = TextEditingController();

  @override
  void dispose() {
    _filtro.dispose();
    super.dispose();
  }

  List<HistorialActividad> get _visibles {
    final q = _filtro.text.trim().toLowerCase();
    if (q.isEmpty) return widget.registros;
    return widget.registros.where((h) {
      final texto = [
        h.accion,
        h.referencia,
        h.actividadTitulo,
        h.apadrinadoNombre,
        h.modificadoPorNombre,
        h.observaciones,
      ].whereType<String>().join(' ').toLowerCase();
      return texto.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        ResponsiveContent(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.conFiltro && widget.registros.isNotEmpty) ...[
                TextField(
                  controller: _filtro,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Filtrar por acción, actividad, persona...',
                    prefixIcon: Icon(Icons.filter_list, size: 20),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (visibles.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.history,
                    title: 'Sin registros',
                    description: 'Las acciones realizadas aparecerán aquí',
                  ),
                )
              else
                for (var i = 0; i < visibles.length; i++)
                  _RegistroTile(registro: visibles[i], ultimo: i == visibles.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegistroTile extends StatelessWidget {
  final HistorialActividad registro;
  final bool ultimo;

  const _RegistroTile({required this.registro, required this.ultimo});

  static IconData _icono(String entidad) {
    switch (entidad) {
      case 'ENTREGA':
        return Icons.upload_file_outlined;
      case 'DOCUMENTO':
        return Icons.attach_file;
      case 'CARTA':
        return Icons.mail_outline;
      case 'EXPORTACION':
        return Icons.file_download_outlined;
      case 'SOLICITUD':
        return Icons.person_add_alt_1_outlined;
      case 'MODULO':
        return Icons.view_module_outlined;
      case 'COMUNIDAD':
        return Icons.location_city_outlined;
      case 'OBSERVACION':
      case 'EXPEDIENTE':
        return Icons.sticky_note_2_outlined;
      case 'ASIGNACION':
        return Icons.assignment_ind_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = registro;
    final color = h.estadoNuevo != null ? AppTheme.getEstadoColor(h.estadoNuevo) : AppColors.darkNavy;
    final referencia = h.actividadTitulo ?? h.referencia;
    final quien = [
      h.modificadoPorNombre ?? 'Sistema',
      if (h.modificadoPorRol != null) '(${h.modificadoPorRol})',
    ].join(' ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
                  child: Icon(_icono(h.entidad), size: 16, color: color),
                ),
                if (!ultimo) Expanded(child: Container(width: 2, color: AppColors.borderLight)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.accionTexto,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                  if (referencia != null && referencia.isNotEmpty)
                    Text(referencia, style: const TextStyle(fontSize: 13, color: AppColors.charcoal)),
                  if (h.apadrinadoNombre != null)
                    Text('Apadrinado: ${h.apadrinadoNombre}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (h.estadoNuevo != null && h.estadoAnterior != h.estadoNuevo) ...[
                    const SizedBox(height: 2),
                    Text(
                      h.estadoAnterior != null
                          ? '${AppTheme.getEstadoTexto(h.estadoAnterior)} → ${AppTheme.getEstadoTexto(h.estadoNuevo)}'
                          : AppTheme.getEstadoTexto(h.estadoNuevo),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                  if (h.observaciones != null && h.observaciones!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(h.observaciones!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text('$quien · ${AppDateUtils.formatDateTime(h.fechaHora)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
