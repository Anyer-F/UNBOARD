import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/asignacion_service.dart';
import '../../services/documento_service.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/asignacion.dart';
import '../../shared/models/carta.dart';
import '../../shared/models/documento.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/status_chip.dart';
import '../documentos/documento_viewer_modal.dart';

/// Actividad asignada al apadrinado.
///
/// - Anuncio / Material de apoyo: contenido y archivos del coordinador;
///   al abrirla queda como "Visto".
/// - Tarea: instrucciones, requisitos y material; preparación de la
///   entrega (documentos, fotografías, evidencias, cartas y comentario),
///   envío para revisión, sugerencias del coordinador y versiones.
///
/// Devuelve `true` al cerrar si hubo cambios.
class AsignacionScreen extends StatefulWidget {
  final int asignacionId;

  const AsignacionScreen({super.key, required this.asignacionId});

  @override
  State<AsignacionScreen> createState() => _AsignacionScreenState();
}

class _AsignacionScreenState extends State<AsignacionScreen> {
  final _service = AsignacionService();
  final _picker = ImagePicker();
  final _comentarioCtrl = TextEditingController();

  AsignacionDetalle? _detalle;
  bool _cargando = true;
  bool _trabajando = false;
  bool _cambios = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar(primeraVez: true);
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool primeraVez = false}) async {
    try {
      var detalle = await _service.detalle(widget.asignacionId);
      // Anuncio o material abierto: pasa a Visto
      if (primeraVez && !detalle.actividad.esTarea && detalle.asignacion.estado == EstadoAsignacion.publicado) {
        try {
          await _service.marcarVisto(widget.asignacionId);
          detalle = await _service.detalle(widget.asignacionId);
          _cambios = true;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _cargando = false;
        _error = null;
        final borrador = detalle.borrador;
        if (primeraVez || borrador == null) {
          _comentarioCtrl.text = borrador?.comentario ?? '';
        }
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
      backgroundColor: error ? AppColors.coralRed : null,
    ));
  }

  /// Ejecuta una operación sobre la entrega y recarga el detalle.
  Future<void> _operacion(Future<void> Function() accion, {String? exito}) async {
    setState(() => _trabajando = true);
    try {
      await accion();
      _cambios = true;
      await _cargar();
      if (exito != null) _mostrar(exito);
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  // ==================== ACCIONES DE LA ENTREGA ====================

  Future<void> _comenzar() => _operacion(() async {
        await _service.iniciarEntrega(widget.asignacionId);
      }, exito: 'Entrega iniciada. Agrega tus archivos y envíala para revisión.');

  Future<void> _subir(Uint8List bytes, String nombre, String tipo) => _operacion(() async {
        await _service.subirArchivo(widget.asignacionId, bytes, nombre, tipo: tipo);
      }, exito: '$nombre agregado a tu entrega');

  Future<void> _elegirArchivo(String tipo) async {
    try {
      final result = await FilePicker.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        _mostrar('No se pudo leer el archivo seleccionado.', error: true);
        return;
      }
      await _subir(file.bytes!, file.name, tipo);
    } catch (e) {
      _mostrar('Error al seleccionar archivo: $e', error: true);
    }
  }

  Future<void> _elegirFoto(ImageSource fuente) async {
    try {
      final xFile = await _picker.pickImage(source: fuente, imageQuality: 85, maxWidth: 1920);
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      await _subir(bytes, xFile.name, 'FOTOGRAFIA');
    } catch (e) {
      _mostrar('Error al obtener la fotografía: $e', error: true);
    }
  }

  Future<void> _quitarArchivo(Documento d) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Quitar archivo',
      message: '¿Quitar "${d.nombreOriginal}" de tu entrega?',
      confirmLabel: 'Quitar',
      isDanger: true,
    );
    if (ok) await _operacion(() => _service.quitarArchivo(widget.asignacionId, d.id));
  }

  Future<void> _editarCarta([Carta? carta]) async {
    final resultado = await showDialog<_CartaEditada>(
      context: context,
      builder: (_) => _CartaDialog(carta: carta),
    );
    if (resultado == null) return;
    await _operacion(() async {
      if (carta == null) {
        await _service.escribirCarta(widget.asignacionId, titulo: resultado.titulo, contenido: resultado.contenido);
      } else {
        await _service.editarCarta(widget.asignacionId, carta.id,
            titulo: resultado.titulo, contenido: resultado.contenido);
      }
    }, exito: carta == null ? 'Carta agregada a tu entrega' : 'Carta actualizada');
  }

  Future<void> _quitarCarta(Carta c) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Quitar carta',
      message: '¿Quitar la carta "${c.titulo}" de tu entrega?',
      confirmLabel: 'Quitar',
      isDanger: true,
    );
    if (ok) await _operacion(() => _service.quitarCarta(widget.asignacionId, c.id));
  }

  Future<void> _enviar() async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Enviar para revisión',
      message: 'Tu coordinador revisará la entrega. Mientras la revisa no podrás modificarla. ¿Deseas enviarla?',
      confirmLabel: 'Enviar',
      icon: Icons.send_outlined,
    );
    if (!ok) return;
    await _operacion(() async {
      await _service.enviar(widget.asignacionId, comentario: _comentarioCtrl.text.trim());
    }, exito: 'Entrega enviada al coordinador');
  }

  // ==================== CONSTRUCCIÓN ====================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _cambios);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_detalle?.actividad.titulo ?? 'Actividad')),
        body: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const LoadingState(message: 'Cargando actividad...');
    if (_detalle == null) {
      return ErrorState(title: 'No se pudo cargar la actividad', message: _error, onRetry: _cargar);
    }
    final d = _detalle!;
    final a = d.actividad;

    final principal = <Widget>[
      _Encabezado(detalle: d),
      const SizedBox(height: AppSpacing.lg),
      _Contenido(actividad: a),
      if (a.adjuntos.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        _Bloque(
          titulo: a.esTarea ? 'Material del coordinador' : 'Archivos',
          icono: Icons.attach_file,
          child: Column(children: [for (final doc in a.adjuntos) _ArchivoTile(documento: doc)]),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
    ];

    final secundario = a.esTarea ? _seccionEntrega(d) : <Widget>[];

    return Stack(
      children: [
        DashboardLayout(
          onRefresh: _cargar,
          principal: principal,
          secundario: secundario,
        ),
        if (_trabajando)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
      ],
    );
  }

  List<Widget> _seccionEntrega(AsignacionDetalle d) {
    final s = d.asignacion;
    final sugerencias = d.sugerencias.reversed.toList();
    final enviadas = d.entregas.where((e) => !e.esBorrador).toList();

    return [
      if (s.enCorreccion && sugerencias.isNotEmpty) ...[
        _Sugerencias(sugerencias: sugerencias),
        const SizedBox(height: AppSpacing.lg),
      ],
      _MensajeEstado(asignacion: s),
      const SizedBox(height: AppSpacing.lg),
      if (d.editable)
        ..._editor(d)
      else if (d.ultimaEnviada != null)
        _Bloque(
          titulo: 'Tu entrega (versión ${d.ultimaEnviada!.version})',
          icono: Icons.inventory_2_outlined,
          child: _ContenidoEntrega(entrega: d.ultimaEnviada!),
        ),
      if (enviadas.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        _Bloque(
          titulo: 'Historial de entregas',
          icono: Icons.history,
          child: Column(children: [for (final e in enviadas) _VersionTile(entrega: e)]),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _editor(AsignacionDetalle d) {
    final borrador = d.borrador;
    final a = d.actividad;
    if (borrador == null) {
      final siguiente = (d.ultima?.version ?? 0) + 1;
      return [
        _Bloque(
          titulo: siguiente > 1 ? 'Corregir tu entrega' : 'Preparar tu entrega',
          icono: Icons.edit_note_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                siguiente > 1
                    ? 'Se creará la versión $siguiente con los archivos de tu entrega anterior para que solo '
                        'cambies lo necesario.'
                    : 'Sube tus documentos, fotografías, evidencias o cartas y envíalos para revisión.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _trabajando ? null : _comenzar,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(siguiente > 1 ? 'Comenzar corrección' : 'Comenzar entrega'),
              ),
            ],
          ),
        ),
      ];
    }

    final fotos = borrador.fotografias;
    final archivos = borrador.archivos;
    return [
      _Bloque(
        titulo: 'Tu entrega (versión ${borrador.version})',
        icono: Icons.edit_note_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (a.requisitos.isNotEmpty) ...[
              _Requisitos(actividad: a, entrega: borrador),
              const SizedBox(height: AppSpacing.md),
            ],
            if (fotos.isEmpty && archivos.isEmpty && borrador.cartas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Text('Aún no has agregado nada a tu entrega.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            if (fotos.isNotEmpty) ...[
              const _Subtitulo('Fotografías'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final f in fotos)
                    _Miniatura(documento: f, onQuitar: _trabajando ? null : () => _quitarArchivo(f)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (archivos.isNotEmpty) ...[
              const _Subtitulo('Documentos y evidencias'),
              for (final doc in archivos)
                _ArchivoTile(documento: doc, onQuitar: _trabajando ? null : () => _quitarArchivo(doc)),
              const SizedBox(height: AppSpacing.md),
            ],
            if (borrador.cartas.isNotEmpty) ...[
              const _Subtitulo('Cartas'),
              for (final c in borrador.cartas)
                _CartaTile(
                  carta: c,
                  onEditar: _trabajando ? null : () => _editarCarta(c),
                  onQuitar: _trabajando ? null : () => _quitarCarta(c),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _BotonAgregar(Icons.upload_file_outlined, 'Subir documento',
                    _trabajando ? null : () => _elegirArchivo('DOCUMENTO')),
                if (!kIsWeb)
                  _BotonAgregar(Icons.photo_camera_outlined, 'Tomar fotografía',
                      _trabajando ? null : () => _elegirFoto(ImageSource.camera)),
                _BotonAgregar(Icons.photo_library_outlined, 'Elegir fotografía',
                    _trabajando ? null : () => _elegirFoto(ImageSource.gallery)),
                _BotonAgregar(Icons.fact_check_outlined, 'Adjuntar evidencia',
                    _trabajando ? null : () => _elegirArchivo('EVIDENCIA')),
                _BotonAgregar(Icons.mail_outline, 'Escribir carta', _trabajando ? null : () => _editarCarta()),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _comentarioCtrl,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Comentario para tu coordinador (opcional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _trabajando ? null : _enviar,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar para revisión'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ),
    ];
  }
}

// ==================== WIDGETS ====================

class _Encabezado extends StatelessWidget {
  final AsignacionDetalle detalle;

  const _Encabezado({required this.detalle});

  @override
  Widget build(BuildContext context) {
    final a = detalle.actividad;
    final s = detalle.asignacion;
    final dias = AppDateUtils.daysUntil(a.fechaLimite);
    final pendiente = s.estado == EstadoAsignacion.pendiente ||
        s.estado == EstadoAsignacion.enProgreso ||
        s.estado == EstadoAsignacion.correccion;
    String? aviso;
    if (a.esTarea && a.fechaLimite != null && pendiente) {
      if (dias < 0) {
        aviso = 'La fecha límite ya pasó';
      } else if (dias == 0) {
        aviso = 'Vence hoy';
      } else if (dias == 1) {
        aviso = 'Vence mañana';
      } else if (dias <= 3) {
        aviso = 'Vence en $dias días';
      }
    }
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [TipoActividadChip(tipo: a.tipo), StatusChip(estado: s.estado)],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(a.titulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
          const SizedBox(height: AppSpacing.sm),
          DatoLinea(
            icon: Icons.folder_outlined,
            texto: [a.comunidadNombre, a.moduloNombre].whereType<String>().join(' · '),
          ),
          if (a.coordinadorNombre != null) ...[
            const SizedBox(height: AppSpacing.xs),
            DatoLinea(icon: Icons.person_outline, texto: 'Coordinador: ${a.coordinadorNombre}'),
          ],
          const SizedBox(height: AppSpacing.xs),
          DatoLinea(icon: Icons.schedule_outlined, texto: 'Publicada: ${AppDateUtils.formatDate(s.fechaAsignacion)}'),
          if (a.esTarea) ...[
            const SizedBox(height: AppSpacing.xs),
            DatoLinea(
              icon: Icons.event_outlined,
              texto: 'Fecha límite: ${AppDateUtils.formatDate(a.fechaLimite)}',
              color: aviso == null
                  ? null
                  : AppDateUtils.isOverdue(a.fechaLimite)
                      ? AppColors.coralRed
                      : AppColors.mustardGold,
            ),
          ],
          if (aviso != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.mustardGold.withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alarm, size: 16, color: AppColors.brownCocoa),
                  const SizedBox(width: AppSpacing.xs),
                  Text(aviso,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brownCocoa)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  final Actividad actividad;

  const _Contenido({required this.actividad});

  @override
  Widget build(BuildContext context) {
    final a = actividad;
    final hayDescripcion = a.descripcion != null && a.descripcion!.isNotEmpty;
    final hayInstrucciones = a.instrucciones != null && a.instrucciones!.isNotEmpty;
    if (!hayDescripcion && !hayInstrucciones && a.requisitos.isEmpty) return const SizedBox.shrink();
    return _Bloque(
      titulo: a.esTarea ? 'Instrucciones' : 'Contenido',
      icono: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hayDescripcion) _Texto(a.descripcion!),
          if (hayDescripcion && hayInstrucciones) const SizedBox(height: AppSpacing.md),
          if (hayInstrucciones) _Texto(a.instrucciones!),
          if (a.esTarea && a.requisitos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const _Subtitulo('Debes entregar'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [for (final r in a.requisitos) Chip(label: Text(r), visualDensity: VisualDensity.compact)],
            ),
          ],
        ],
      ),
    );
  }
}

/// Requisitos con indicador de si la entrega en preparación los cumple.
class _Requisitos extends StatelessWidget {
  final Actividad actividad;
  final Entrega entrega;

  const _Requisitos({required this.actividad, required this.entrega});

  @override
  Widget build(BuildContext context) {
    final a = actividad;
    final items = <(String, bool)>[
      if (a.requiereDocumento) ('Documento', entrega.archivos.isNotEmpty),
      if (a.requiereFotografia) ('Fotografía', entrega.fotografias.isNotEmpty),
      if (a.requiereCarta) ('Carta', entrega.cartas.isNotEmpty),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (nombre, listo) in items)
              Chip(
                avatar: Icon(listo ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16, color: listo ? AppColors.sageGreen : AppColors.textTertiary),
                label: Text(nombre),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (a.otrosRequisitos != null && a.otrosRequisitos!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text('También: ${a.otrosRequisitos}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}

class _Sugerencias extends StatelessWidget {
  final List<Sugerencia> sugerencias;

  const _Sugerencias({required this.sugerencias});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.coralRed.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.coralRed.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.feedback_outlined, color: AppColors.coralRed),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Sugerencias de tu coordinador',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.coralRed)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < sugerencias.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sugerencias[i].texto,
                    style: TextStyle(
                      fontSize: i == 0 ? 14 : 13,
                      fontWeight: i == 0 ? FontWeight.w600 : FontWeight.normal,
                      color: i == 0 ? AppColors.charcoal : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Versión ${sugerencias[i].version ?? '-'} · ${AppDateUtils.formatDateTime(sugerencias[i].fecha)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MensajeEstado extends StatelessWidget {
  final Asignacion asignacion;

  const _MensajeEstado({required this.asignacion});

  @override
  Widget build(BuildContext context) {
    final s = asignacion;
    final (texto, icono) = switch (s.estado) {
      EstadoAsignacion.pendiente => ('Aún no has comenzado esta tarea.', Icons.hourglass_empty),
      EstadoAsignacion.enProgreso => ('Estás preparando tu entrega. Envíala cuando esté lista.', Icons.edit_outlined),
      EstadoAsignacion.enviado => (
          'Enviaste tu entrega el ${AppDateUtils.formatDateTime(s.fechaEnvio)}. Espera la revisión de tu coordinador.',
          Icons.mark_email_read_outlined
        ),
      EstadoAsignacion.enRevision => ('Tu coordinador está revisando tu entrega.', Icons.rate_review_outlined),
      EstadoAsignacion.correccion => (
          'Tu coordinador pidió correcciones. Revisa las sugerencias, corrige y vuelve a enviar.',
          Icons.edit_note_outlined
        ),
      EstadoAsignacion.aprobado => (
          '¡Tu entrega fue aprobada el ${AppDateUtils.formatDate(s.fechaAprobacion)}! Actividad realizada.',
          Icons.verified_outlined
        ),
      EstadoAsignacion.vencido => (
          'La fecha límite pasó sin que enviaras tu entrega. Aún puedes enviarla.',
          Icons.event_busy_outlined
        ),
      _ => ('Estado: ${AppTheme.getEstadoTexto(s.estado)}', Icons.info_outline),
    };
    final color = AppTheme.getEstadoColor(s.estado);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Contenido de solo lectura de una versión enviada.
class _ContenidoEntrega extends StatelessWidget {
  final Entrega entrega;

  const _ContenidoEntrega({required this.entrega});

  @override
  Widget build(BuildContext context) {
    final e = entrega;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enviada: ${AppDateUtils.formatDateTime(e.fechaEnvio)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        if (e.fotografias.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const _Subtitulo('Fotografías'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final f in e.fotografias) _Miniatura(documento: f)],
          ),
        ],
        if (e.archivos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const _Subtitulo('Documentos y evidencias'),
          for (final d in e.archivos) _ArchivoTile(documento: d),
        ],
        if (e.cartas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const _Subtitulo('Cartas'),
          for (final c in e.cartas) _CartaTile(carta: c),
        ],
        if (e.comentario != null && e.comentario!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const _Subtitulo('Tu comentario'),
          _Texto(e.comentario!),
        ],
      ],
    );
  }
}

class _VersionTile extends StatelessWidget {
  final Entrega entrega;

  const _VersionTile({required this.entrega});

  @override
  Widget build(BuildContext context) {
    final e = entrega;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        title: Text('Versión ${e.version}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${AppTheme.getEstadoTexto(e.estado)} · ${AppDateUtils.formatDateTime(e.fechaEnvio)}',
          style: TextStyle(fontSize: 12, color: AppTheme.getEstadoColor(e.estado)),
        ),
        children: [
          _ContenidoEntrega(entrega: e),
          for (final s in e.sugerencias)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.coralRed.withAlpha(15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text('Sugerencia: ${s.texto}', style: const TextStyle(fontSize: 12, color: AppColors.coralRed)),
            ),
        ],
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;

  const _Bloque({required this.titulo, required this.icono, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: AppColors.darkNavy),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final String texto;

  const _Subtitulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(texto,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}

class _Texto extends StatelessWidget {
  final String texto;

  const _Texto(this.texto);

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.charcoal));
}

class _BotonAgregar extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback? onPressed;

  const _BotonAgregar(this.icono, this.texto, this.onPressed);

  @override
  Widget build(BuildContext context) =>
      OutlinedButton.icon(onPressed: onPressed, icon: Icon(icono, size: 18), label: Text(texto));
}

class _ArchivoTile extends StatelessWidget {
  final Documento documento;
  final VoidCallback? onQuitar;

  const _ArchivoTile({required this.documento, this.onQuitar});

  @override
  Widget build(BuildContext context) {
    final d = documento;
    final icono = d.isPdf
        ? Icons.picture_as_pdf_outlined
        : d.isImage
            ? Icons.image_outlined
            : d.tipoDocumento == 'EVIDENCIA'
                ? Icons.fact_check_outlined
                : Icons.insert_drive_file_outlined;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icono, color: AppColors.darkNavy),
      title: Text(d.nombreOriginal, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (d.tipoDocumento == 'EVIDENCIA') 'Evidencia',
          if (d.tamanioBytes != null) d.tamanioTexto,
          if (d.descripcion != null && d.descripcion!.isNotEmpty) d.descripcion!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => DocumentoViewerModal.mostrar(context, d),
      trailing: onQuitar == null
          ? const Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary)
          : IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.close, color: AppColors.coralRed),
              onPressed: onQuitar,
            ),
    );
  }
}

class _CartaTile extends StatelessWidget {
  final Carta carta;
  final VoidCallback? onEditar;
  final VoidCallback? onQuitar;

  const _CartaTile({required this.carta, this.onEditar, this.onQuitar});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.mail_outline, color: AppColors.tealCyan),
      title: Text(carta.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(carta.contenido, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onEditar ??
          () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(carta.titulo),
                  content: SingleChildScrollView(child: Text(carta.contenido)),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
                ),
              ),
      trailing: onQuitar == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: onEditar),
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close, color: AppColors.coralRed),
                  onPressed: onQuitar,
                ),
              ],
            ),
    );
  }
}

/// Miniatura de una fotografía descargada del repositorio de documentos.
class _Miniatura extends StatefulWidget {
  final Documento documento;
  final VoidCallback? onQuitar;

  const _Miniatura({required this.documento, this.onQuitar});

  @override
  State<_Miniatura> createState() => _MiniaturaState();
}

class _MiniaturaState extends State<_Miniatura> {
  static final Map<String, Uint8List> _cache = {};
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    final clave = widget.documento.nombreAlmacenado;
    _bytes = _cache.containsKey(clave)
        ? Future.value(_cache[clave])
        : DocumentoService().descargar(widget.documento).then((b) => _cache[clave] = b);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: () => DocumentoViewerModal.mostrar(context, widget.documento),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: 96,
              height: 96,
              color: AppColors.surfaceVariant,
              child: FutureBuilder<Uint8List>(
                future: _bytes,
                builder: (context, snap) {
                  if (snap.hasData) {
                    return Image.memory(snap.data!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
                  }
                  if (snap.hasError) return const Icon(Icons.image_not_supported_outlined);
                  return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                },
              ),
            ),
          ),
        ),
        if (widget.onQuitar != null)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onQuitar,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CartaEditada {
  final String? titulo;
  final String contenido;

  _CartaEditada(this.titulo, this.contenido);
}

class _CartaDialog extends StatefulWidget {
  final Carta? carta;

  const _CartaDialog({this.carta});

  @override
  State<_CartaDialog> createState() => _CartaDialogState();
}

class _CartaDialogState extends State<_CartaDialog> {
  late final _titulo = TextEditingController(text: widget.carta?.titulo ?? '');
  late final _contenido = TextEditingController(text: widget.carta?.contenido ?? '');
  String? _error;

  @override
  void dispose() {
    _titulo.dispose();
    _contenido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.carta == null ? 'Escribir carta' : 'Editar carta'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título (opcional)', hintText: 'Querido padrino'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _contenido,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: 'Carta',
                  alignLabelWithHint: true,
                  errorText: _error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_contenido.text.trim().isEmpty) {
              setState(() => _error = 'Escribe el contenido de la carta');
              return;
            }
            Navigator.pop(
              context,
              _CartaEditada(_titulo.text.trim().isEmpty ? null : _titulo.text.trim(), _contenido.text.trim()),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
