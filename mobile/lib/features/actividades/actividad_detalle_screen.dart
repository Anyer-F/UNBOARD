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
import '../../shared/models/actividad.dart';
import '../../shared/models/asignacion.dart';
import '../../shared/models/documento.dart';
import '../../shared/models/expediente.dart';
import '../../shared/models/modulo.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/states.dart';
import '../documentos/documento_viewer_modal.dart';
import '../historial/historial_screen.dart';
import 'crear_actividad_screen.dart';
import 'revisar_entrega_screen.dart';

/// Detalle de una actividad (coordinador): datos, contenido, avance y la
/// lista de apadrinados asignados con su estado. Desde aquí se edita,
/// mueve, elimina y se generan el PDF y el ZIP de la actividad.
class ActividadDetalleScreen extends StatefulWidget {
  final int actividadId;

  const ActividadDetalleScreen({super.key, required this.actividadId});

  @override
  State<ActividadDetalleScreen> createState() => _ActividadDetalleScreenState();
}

class _ActividadDetalleScreenState extends State<ActividadDetalleScreen> {
  final _actividadService = ActividadService();
  final _expedienteService = ExpedienteService();

  ActividadDetalle? _detalle;
  bool _cargando = true;
  String? _error;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final d = await _actividadService.detalle(widget.actividadId);
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

  // ==================== ACCIONES ====================

  Future<void> _editar() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CrearActividadScreen(actividadId: widget.actividadId)),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _mover() async {
    final a = _detalle!.actividad;
    if (a.comunidadId == null) return;
    List<Modulo> modulos;
    try {
      modulos = await ComunidadService().modulos(a.comunidadId!);
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
      return;
    }
    if (!mounted) return;
    if (modulos.length < 2) {
      _mostrar('La comunidad tiene un solo módulo. Cree otro módulo para mover la actividad.', error: true);
      return;
    }
    final destino = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Mover a otro módulo'),
        children: [
          for (final m in modulos)
            SimpleDialogOption(
              onPressed: m.id == a.moduloId ? null : () => Navigator.pop(ctx, m.id),
              child: Row(
                children: [
                  Icon(m.id == a.moduloId ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 18, color: AppColors.darkNavy),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(m.nombre)),
                ],
              ),
            ),
        ],
      ),
    );
    if (destino == null) return;
    try {
      final d = await _actividadService.moverAModulo(a.id, destino);
      setState(() => _detalle = d);
      _mostrar('Actividad movida a ${d.actividad.moduloNombre ?? 'otro módulo'}');
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    }
  }

  Future<void> _eliminar() async {
    final a = _detalle!.actividad;
    try {
      if (!_detalle!.tieneEntregas) {
        final ok = await showConfirmationDialog(
          context,
          title: 'Eliminar actividad',
          message: '¿Eliminar "${a.titulo}"? No tiene entregas, por lo que se eliminará de forma definitiva.',
          confirmLabel: 'Eliminar',
          isDanger: true,
          icon: Icons.delete_outline,
        );
        if (!ok) return;
      }
      String resultado;
      try {
        resultado = await _actividadService.eliminar(a.id);
      } on ApiException catch (e) {
        if (!e.requiereConfirmacion || !mounted) rethrow;
        final ok = await showConfirmationDialog(
          context,
          title: 'La actividad tiene entregas',
          message: e.message,
          confirmLabel: 'Eliminar de todos modos',
          isDanger: true,
          icon: Icons.warning_amber_rounded,
        );
        if (!ok) return;
        resultado = await _actividadService.eliminar(a.id, confirmar: true);
      }
      if (!mounted) return;
      _mostrar(resultado == 'LOGICA'
          ? 'Actividad eliminada. Sus entregas se conservan en los expedientes.'
          : 'Actividad eliminada');
      Navigator.pop(context, true);
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    }
  }

  void _historial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialScreen(
          actividadId: widget.actividadId,
          titulo: 'Historial · ${_detalle?.actividad.titulo ?? 'Actividad'}',
        ),
      ),
    );
  }

  Future<void> _exportar({required bool zip}) async {
    setState(() => _exportando = true);
    try {
      final Exportacion e = zip
          ? await _actividadService.exportarZip(widget.actividadId)
          : await _actividadService.exportarPdf(widget.actividadId);
      final mensaje = await _expedienteService.descargarYAbrir(e);
      _mostrar(mensaje);
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _abrirAsignacion(Asignacion s) async {
    if (!(_detalle?.actividad.esTarea ?? false)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RevisarEntregaScreen(asignacionId: s.id)),
    );
    await _cargar();
  }

  // ==================== INTERFAZ ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de actividad'),
        actions: [
          if (_detalle != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'editar':
                    _editar();
                  case 'mover':
                    _mover();
                  case 'historial':
                    _historial();
                  case 'eliminar':
                    _eliminar();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: _ItemMenu(Icons.edit_outlined, 'Editar')),
                PopupMenuItem(value: 'mover', child: _ItemMenu(Icons.drive_file_move_outlined, 'Mover a otro módulo')),
                PopupMenuItem(value: 'historial', child: _ItemMenu(Icons.history, 'Historial')),
                PopupMenuItem(
                  value: 'eliminar',
                  child: _ItemMenu(Icons.delete_outline, 'Eliminar', color: AppColors.coralRed),
                ),
              ],
            ),
        ],
      ),
      body: _cargando
          ? const LoadingState(message: 'Cargando actividad...')
          : _error != null
              ? ErrorState(title: 'No se pudo cargar la actividad', message: _error, onRetry: _cargar)
              : _cuerpo(),
    );
  }

  Widget _cuerpo() {
    final d = _detalle!;
    final a = d.actividad;
    return DashboardLayout(
      onRefresh: _cargar,
      principal: [
        _encabezado(a),
        if (a.descripcion != null && a.descripcion!.isNotEmpty) _bloqueTexto('Descripción', a.descripcion!),
        if (a.instrucciones != null && a.instrucciones!.isNotEmpty) _bloqueTexto('Instrucciones', a.instrucciones!),
        if (a.adjuntos.isNotEmpty) _adjuntos(a.adjuntos),
        if (a.esTarea) _exportacion(d),
      ],
      secundario: [
        _asignados(d),
      ],
    );
  }

  Widget _tarjeta(Widget child) => AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      );

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
      );

  Widget _encabezado(Actividad a) {
    return _tarjeta(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TipoActividadChip(tipo: a.tipo),
        const SizedBox(height: AppSpacing.sm),
        Text(a.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
        const SizedBox(height: AppSpacing.sm),
        DatoLinea(
          icon: Icons.folder_outlined,
          texto: [a.comunidadNombre, a.moduloNombre].whereType<String>().join(' · '),
        ),
        const SizedBox(height: AppSpacing.xs),
        DatoLinea(
          icon: Icons.groups_outlined,
          texto: a.asignadaAComunidad ? 'Asignada a toda la comunidad' : 'Asignada a apadrinados seleccionados',
        ),
        if (a.esTarea) ...[
          const SizedBox(height: AppSpacing.xs),
          DatoLinea(
            icon: Icons.event_outlined,
            texto: 'Fecha límite: ${AppDateUtils.formatDate(a.fechaLimite)}',
            color: AppDateUtils.isOverdue(a.fechaLimite) ? AppColors.coralRed : null,
          ),
          if (a.requisitos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('Requisitos de entrega', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [for (final r in a.requisitos) Chip(label: Text(r), visualDensity: VisualDensity.compact)],
            ),
          ],
        ],
        if (a.resumen != null) ...[
          const SizedBox(height: AppSpacing.lg),
          ResumenAvanceWidget(resumen: a.resumen!, esTarea: a.esTarea),
        ],
      ],
    ));
  }

  Widget _bloqueTexto(String titulo, String texto) {
    return _tarjeta(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo(titulo),
        SelectableText(texto, style: const TextStyle(fontSize: 14, color: AppColors.charcoal, height: 1.4)),
      ],
    ));
  }

  Widget _adjuntos(List<Documento> docs) {
    return _tarjeta(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Contenido del coordinador'),
        for (final doc in docs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(doc.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                color: AppColors.darkNavy),
            title: Text(doc.nombreOriginal, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(doc.tamanioTexto),
            trailing: const Icon(Icons.visibility_outlined),
            onTap: () => DocumentoViewerModal.mostrar(context, doc),
          ),
      ],
    ));
  }

  Widget _exportacion(ActividadDetalle d) {
    final habilitado = d.exportable && !_exportando;
    return _tarjeta(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Expediente de la actividad'),
        Text(
          d.exportable
              ? 'Incluye solo las entregas aprobadas.'
              : 'Disponible cuando haya al menos una entrega aprobada.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ElevatedButton.icon(
              onPressed: habilitado ? () => _exportar(zip: false) : null,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Expediente PDF'),
            ),
            OutlinedButton.icon(
              onPressed: habilitado ? () => _exportar(zip: true) : null,
              icon: const Icon(Icons.folder_zip_outlined),
              label: const Text('Carpeta ZIP'),
            ),
            if (_exportando)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
      ],
    ));
  }

  Widget _asignados(ActividadDetalle d) {
    final a = d.actividad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Apadrinados asignados (${d.asignaciones.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal),
          ),
        ),
        if (a.esTarea)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Toque un apadrinado para revisar su entrega.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        if (d.asignaciones.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Text('Aún no hay apadrinados asignados.', style: TextStyle(color: AppColors.textSecondary)),
          ),
        for (final s in d.asignaciones)
          AsignacionCard(
            asignacion: s,
            porApadrinado: true,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            onTap: a.esTarea ? () => _abrirAsignacion(s) : null,
          ),
      ],
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color? color;

  const _ItemMenu(this.icon, this.texto, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.darkNavy;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Text(texto, style: TextStyle(color: color)),
      ],
    );
  }
}
