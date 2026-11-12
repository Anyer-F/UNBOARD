import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/asignacion_service.dart';
import '../../services/documento_service.dart';
import '../../shared/models/asignacion.dart';
import '../../shared/models/carta.dart';
import '../../shared/models/documento.dart';
import '../../shared/models/historial_actividad.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/status_chip.dart';
import '../documentos/documento_viewer_modal.dart';

/// Revisión de la entrega de un apadrinado (coordinador): documentos,
/// fotografías, cartas, evidencias y comentarios de la última versión
/// enviada; aprobar o solicitar correcciones con sugerencias de mejora.
class RevisarEntregaScreen extends StatefulWidget {
  final int asignacionId;

  const RevisarEntregaScreen({super.key, required this.asignacionId});

  @override
  State<RevisarEntregaScreen> createState() => _RevisarEntregaScreenState();
}

class _RevisarEntregaScreenState extends State<RevisarEntregaScreen> {
  final _service = AsignacionService();

  AsignacionDetalle? _detalle;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar(iniciar: true);
  }

  Future<void> _cargar({bool iniciar = false}) async {
    try {
      var d = await _service.detalle(widget.asignacionId);
      // Al abrir una entrega recién enviada comienza la revisión
      if (iniciar && d.asignacion.estado == EstadoAsignacion.enviado) {
        await _service.iniciarRevision(widget.asignacionId);
        d = await _service.detalle(widget.asignacionId);
      }
      if (!mounted) return;
      setState(() {
        _detalle = d;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  void _mostrar(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? AppColors.coralRed : AppColors.sageGreen,
    ));
  }

  /// Diálogo de texto; con [obligatorio] no deja confirmar vacío.
  Future<String?> _pedirTexto({
    required String titulo,
    required String etiqueta,
    required String confirmar,
    String? ayuda,
    bool obligatorio = false,
    Color? color,
  }) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ayuda != null) ...[
                  Text(ayuda, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: etiqueta, alignLabelWithHint: true),
                  validator: (v) =>
                      obligatorio && (v == null || v.trim().isEmpty) ? 'Este campo es obligatorio' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: color != null ? ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white) : null,
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
            },
            child: Text(confirmar),
          ),
        ],
      ),
    );
  }

  Future<void> _aprobar() async {
    final texto = await _pedirTexto(
      titulo: 'Aprobar entrega',
      etiqueta: 'Observación (opcional)',
      ayuda: 'La actividad quedará completada satisfactoriamente. La observación se guarda en el expediente.',
      confirmar: 'Aprobar',
      color: AppColors.sageGreen,
    );
    if (texto == null) return;
    await _accion(() => _service.aprobar(widget.asignacionId, observacion: texto), 'Entrega aprobada');
  }

  Future<void> _corregir() async {
    final texto = await _pedirTexto(
      titulo: 'Solicitar corrección',
      etiqueta: 'Sugerencias de mejora',
      ayuda: 'Explique qué debe corregir el apadrinado. Recibirá una notificación con estas sugerencias.',
      confirmar: 'Enviar sugerencias',
      obligatorio: true,
      color: AppColors.coralRed,
    );
    if (texto == null) return;
    await _accion(() => _service.solicitarCorreccion(widget.asignacionId, texto), 'Corrección solicitada');
  }

  Future<void> _accion(Future<void> Function() accion, String exito) async {
    setState(() => _procesando = true);
    try {
      await accion();
      _mostrar(exito);
      await _cargar();
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _verHistorial() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HistorialSheet(cargar: () => _service.historial(widget.asignacionId)),
    );
  }

  // ==================== INTERFAZ ====================

  @override
  Widget build(BuildContext context) {
    final d = _detalle;
    final puedeRevisar = d != null && d.asignacion.estado == EstadoAsignacion.enRevision;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar entrega'),
        actions: [
          IconButton(tooltip: 'Historial', icon: const Icon(Icons.history), onPressed: _verHistorial),
        ],
      ),
      bottomNavigationBar: puedeRevisar ? _barraAcciones() : null,
      body: _cargando
          ? const LoadingState(message: 'Cargando entrega...')
          : _error != null
              ? ErrorState(title: 'No se pudo cargar la entrega', message: _error, onRetry: _cargar)
              : _cuerpo(d!),
    );
  }

  Widget _barraAcciones() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        // heightFactor: 1 — sin él, Center ocupa todo el alto y tapa el cuerpo
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coralRed,
                      side: const BorderSide(color: AppColors.coralRed),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _procesando ? null : _corregir,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Solicitar corrección'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _procesando ? null : _aprobar,
                    icon: _procesando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(AsignacionDetalle d) {
    final enviada = d.ultimaEnviada;
    final anteriores = d.entregas.where((e) => !e.esBorrador && e.id != enviada?.id).toList();
    return DashboardLayout(
      onRefresh: _cargar,
      principal: [
        _encabezado(d),
        _estado(d),
        if (enviada != null) _entrega(enviada, actual: true),
      ],
      secundario: [
        _requisitos(d),
        if (anteriores.isNotEmpty) _anteriores(anteriores),
      ],
    );
  }

  Widget _tarjeta(Widget child, {Color? color}) => AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: color,
        child: child,
      );

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
      );

  Widget _encabezado(AsignacionDetalle d) {
    final a = d.actividad;
    final s = d.asignacion;
    return _tarjeta(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.apadrinadoNombre ?? 'Apadrinado',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
            ),
            StatusChip(estado: s.estado),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DatoLinea(icon: Icons.assignment_outlined, texto: a.titulo),
        const SizedBox(height: AppSpacing.xs),
        DatoLinea(icon: Icons.folder_outlined, texto: [a.comunidadNombre, a.moduloNombre].whereType<String>().join(' · ')),
        if (a.fechaLimite != null) ...[
          const SizedBox(height: AppSpacing.xs),
          DatoLinea(icon: Icons.event_outlined, texto: 'Fecha límite: ${AppDateUtils.formatDate(a.fechaLimite)}'),
        ],
        if (s.fechaEnvio != null) ...[
          const SizedBox(height: AppSpacing.xs),
          DatoLinea(icon: Icons.upload_outlined, texto: 'Enviado: ${AppDateUtils.formatDateTime(s.fechaEnvio)}'),
        ],
        if (s.fechaAprobacion != null) ...[
          const SizedBox(height: AppSpacing.xs),
          DatoLinea(icon: Icons.verified_outlined, texto: 'Aprobado: ${AppDateUtils.formatDateTime(s.fechaAprobacion)}'),
        ],
      ],
    ));
  }

  Widget _estado(AsignacionDetalle d) {
    final s = d.asignacion;
    late final IconData icono;
    late final Color color;
    late final String texto;
    switch (s.estado) {
      case EstadoAsignacion.enRevision:
        icono = Icons.rate_review_outlined;
        color = AppColors.darkNavy;
        texto = 'Revise la entrega y apruébela o solicite correcciones.';
      case EstadoAsignacion.aprobado:
        icono = Icons.check_circle_outline;
        color = AppColors.sageGreen;
        texto = 'Entrega aprobada: la actividad se completó satisfactoriamente.';
      case EstadoAsignacion.correccion:
        icono = Icons.edit_note;
        color = AppColors.coralRed;
        texto = 'Corrección solicitada. Esperando una nueva versión del apadrinado.'
            '${s.ultimaSugerencia != null ? '\nSugerencias: ${s.ultimaSugerencia}' : ''}';
      case EstadoAsignacion.vencido:
        icono = Icons.timer_off_outlined;
        color = AppColors.brownCocoa;
        texto = 'La fecha límite pasó sin que el apadrinado enviara su entrega.';
      case EstadoAsignacion.enviado:
        icono = Icons.inbox_outlined;
        color = AppColors.darkNavy;
        texto = 'Entrega recibida.';
      default:
        icono = Icons.hourglass_empty;
        color = AppColors.mustardGold;
        texto = 'El apadrinado aún no ha enviado su entrega.';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _requisitos(AsignacionDetalle d) {
    final a = d.actividad;
    return _tarjeta(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Lo que se pidió'),
        if (a.instrucciones != null && a.instrucciones!.isNotEmpty)
          Text(a.instrucciones!, style: const TextStyle(fontSize: 13, color: AppColors.charcoal))
        else if (a.descripcion != null && a.descripcion!.isNotEmpty)
          Text(a.descripcion!, style: const TextStyle(fontSize: 13, color: AppColors.charcoal)),
        if (a.requisitos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [for (final r in a.requisitos) Chip(label: Text(r), visualDensity: VisualDensity.compact)],
          ),
        ],
      ],
    ));
  }

  /// Contenido de una versión de la entrega.
  Widget _entrega(Entrega e, {bool actual = false}) {
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actual) _titulo('Entrega · versión ${e.version}'),
        Text(
          'Enviada: ${AppDateUtils.formatDateTime(e.fechaEnvio)}'
          '${e.revisorNombre != null && e.fechaRevision != null ? ' · Revisada por ${e.revisorNombre}' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (e.comentario != null && e.comentario!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text('Comentario del apadrinado: ${e.comentario}',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          ),
        ],
        if (e.fotografias.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Fotografías', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final f in e.fotografias) _Miniatura(documento: f)],
          ),
        ],
        if (e.archivos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Documentos y evidencias', style: TextStyle(fontWeight: FontWeight.w600)),
          for (final doc in e.archivos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                doc.tipoDocumento == 'EVIDENCIA' ? Icons.fact_check_outlined : Icons.description_outlined,
                color: AppColors.darkNavy,
              ),
              title: Text(doc.nombreOriginal, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                doc.tipoDocumento == 'EVIDENCIA' ? 'Evidencia' : 'Documento',
                doc.tamanioTexto,
                if (doc.descripcion != null && doc.descripcion!.isNotEmpty) doc.descripcion!,
              ].join(' · ')),
              trailing: const Icon(Icons.visibility_outlined),
              onTap: () => DocumentoViewerModal.mostrar(context, doc),
            ),
        ],
        if (e.cartas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Cartas', style: TextStyle(fontWeight: FontWeight.w600)),
          for (final c in e.cartas) _carta(c),
        ],
        if (e.documentos.isEmpty && e.cartas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text('Esta versión no tiene archivos.', style: TextStyle(color: AppColors.textSecondary)),
          ),
        if (e.sugerencias.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final s in e.sugerencias)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.coralRed.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Sugerencias (${AppDateUtils.formatDateTime(s.fecha)}): ${s.texto}',
                style: const TextStyle(fontSize: 12, color: AppColors.coralRed),
              ),
            ),
        ],
      ],
    );
    return actual ? _tarjeta(contenido) : contenido;
  }

  Widget _carta(Carta c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mustardGold.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.mustardGold.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(c.contenido, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _anteriores(List<Entrega> entregas) {
    return _tarjeta(Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text('Versiones anteriores (${entregas.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        children: [
          for (final e in entregas)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Versión ${e.version}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: AppSpacing.sm),
                      StatusChip(estado: e.estado),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _entrega(e),
                  const Divider(),
                ],
              ),
            ),
        ],
      ),
    ));
  }
}

/// Miniatura de una fotografía; al tocarla se abre el visor.
class _Miniatura extends StatefulWidget {
  final Documento documento;

  const _Miniatura({required this.documento});

  @override
  State<_Miniatura> createState() => _MiniaturaState();
}

class _MiniaturaState extends State<_Miniatura> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    DocumentoService().descargar(widget.documento).then((b) {
      if (mounted) setState(() => _bytes = b);
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => DocumentoViewerModal.mostrar(context, widget.documento),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: _bytes != null
            ? Image.memory(_bytes!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icono())
            : _error
                ? _icono()
                : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }

  Widget _icono() => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary));
}

/// Historial de la asignación en una hoja inferior.
class _HistorialSheet extends StatelessWidget {
  final Future<List<HistorialActividad>> Function() cargar;

  const _HistorialSheet({required this.cargar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: FutureBuilder<List<HistorialActividad>>(
        future: cargar(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingState();
          if (snap.hasError) {
            return ErrorState(title: 'No se pudo cargar el historial', message: mensajeDeError(snap.error!));
          }
          final lista = snap.data ?? [];
          if (lista.isEmpty) {
            return const EmptyState(icon: Icons.history, title: 'Sin registros');
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                itemCount: lista.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text('Historial de la entrega',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    );
                  }
                  final h = lista[i - 1];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, size: 10, color: AppColors.tealCyan),
                    title: Text(h.accionTexto, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (h.observaciones != null && h.observaciones!.isNotEmpty) h.observaciones!,
                      '${h.modificadoPorNombre ?? 'Sistema'} · ${AppDateUtils.formatDateTime(h.fechaHora)}',
                    ].join('\n')),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
