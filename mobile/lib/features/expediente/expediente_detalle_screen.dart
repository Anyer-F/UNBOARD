import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/documento_service.dart';
import '../../services/expediente_service.dart';
import '../../shared/models/carta.dart';
import '../../shared/models/documento.dart';
import '../../shared/models/expediente.dart';
import '../../shared/models/historial_actividad.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/states.dart';
import '../actividades/revisar_entrega_screen.dart';
import '../documentos/documento_viewer_modal.dart';
import '../historial/historial_screen.dart';

/// Expediente digital de un apadrinado (función exclusiva del
/// coordinador): datos personales, actividades, documentos, fotografías,
/// cartas, observaciones e historial. Desde aquí se generan el
/// expediente PDF y la carpeta ZIP por intervalo de tiempo.
class ExpedienteDetalleScreen extends StatefulWidget {
  final int apadrinadoId;

  const ExpedienteDetalleScreen({super.key, required this.apadrinadoId});

  @override
  State<ExpedienteDetalleScreen> createState() => _ExpedienteDetalleScreenState();
}

class _ExpedienteDetalleScreenState extends State<ExpedienteDetalleScreen> {
  final _servicio = ExpedienteService();

  Expediente? _expediente;
  List<HistorialActividad>? _historial;
  bool _isLoading = true;
  String? _error;

  DateTimeRange? _periodo;
  String? _exportando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = _expediente == null;
      _error = null;
    });
    try {
      final e = await _servicio.obtenerPorApadrinado(widget.apadrinadoId);
      if (mounted) {
        setState(() {
          _expediente = e;
          _isLoading = false;
          _historial = null;
        });
      }
      _cargarHistorial();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Future<void> _cargarHistorial() async {
    try {
      final h = await _servicio.historial(widget.apadrinadoId);
      if (mounted) setState(() => _historial = h);
    } catch (_) {
      if (mounted) setState(() => _historial = const []);
    }
  }

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? AppColors.coralRed : null),
    );
  }

  // ==================== EXPORTACIÓN ====================

  Future<void> _elegirPeriodo() async {
    final hoy = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoy.year + 1, 12, 31),
      initialDateRange: _periodo ?? DateTimeRange(start: DateTime(hoy.year, hoy.month - 3, hoy.day), end: hoy),
      helpText: 'Intervalo del expediente',
      saveText: 'Aplicar',
    );
    if (r != null) setState(() => _periodo = r);
  }

  Future<void> _exportar(bool pdf) async {
    setState(() => _exportando = pdf ? 'pdf' : 'zip');
    try {
      final e = pdf
          ? await _servicio.exportarPdf(widget.apadrinadoId, desde: _periodo?.start, hasta: _periodo?.end)
          : await _servicio.exportarZip(widget.apadrinadoId, desde: _periodo?.start, hasta: _periodo?.end);
      final mensaje = await _servicio.descargarYAbrir(e);
      if (mounted) _aviso(mensaje);
      _cargarHistorial();
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _exportando = null);
    }
  }

  // ==================== OBSERVACIONES ====================

  Future<void> _agregarObservacion() async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva observación'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Escriba la observación para el expediente'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (texto == null || texto.isEmpty || !mounted) return;
    try {
      await _servicio.agregarObservacion(widget.apadrinadoId, texto);
      if (mounted) {
        _aviso('Observación registrada');
        _cargar();
      }
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    }
  }

  Future<void> _eliminarObservacion(Observacion o) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Eliminar observación',
      message: '¿Eliminar esta observación del expediente?',
      confirmLabel: 'Eliminar',
      isDanger: true,
    );
    if (!ok || !mounted) return;
    try {
      await _servicio.eliminarObservacion(o.id);
      if (mounted) _cargar();
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    }
  }

  Future<void> _abrirRevision(int asignacionId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RevisarEntregaScreen(asignacionId: asignacionId)),
    );
    if (mounted) _cargar();
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final e = _expediente;
    final nombre = e?.apadrinado?.nombreCompleto;
    return Scaffold(
      appBar: AppBar(title: Text(nombre != null && nombre.isNotEmpty ? nombre : 'Expediente')),
      body: _isLoading
          ? const LoadingState(message: 'Cargando expediente...')
          : e == null
              ? ErrorState(title: 'No se pudo cargar el expediente', message: _error, onRetry: _cargar)
              : DefaultTabController(
                  length: 6,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      SliverToBoxAdapter(
                        child: ResponsiveContent(
                          maxWidth: 1000,
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.isLarge(context) ? 24 : 16,
                            vertical: AppSpacing.lg,
                          ),
                          child: _cabecera(e),
                        ),
                      ),
                      SliverPersistentHeader(pinned: true, delegate: _TabsDelegate(_tabs(e))),
                    ],
                    body: TabBarView(
                      children: [
                        _tabActividades(e),
                        _tabDocumentos(e),
                        _tabFotografias(e),
                        _tabCartas(e),
                        _tabObservaciones(e),
                        _historial == null
                            ? const LoadingState(message: 'Cargando historial...')
                            : HistorialLista(registros: _historial!),
                      ],
                    ),
                  ),
                ),
    );
  }

  TabBar _tabs(Expediente e) => TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelColor: AppColors.darkNavy,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.tealCyan,
        tabs: [
          Tab(text: 'Actividades (${e.totalActividades})'),
          Tab(text: 'Documentos (${e.totalDocumentos})'),
          Tab(text: 'Fotografías (${e.fotografias.length})'),
          Tab(text: 'Cartas (${e.cartas.length})'),
          Tab(text: 'Observaciones (${e.observaciones.length})'),
          const Tab(text: 'Historial'),
        ],
      );

  Widget _cabecera(Expediente e) {
    final a = e.apadrinado;
    String v(String? s) => s == null || s.isEmpty ? 'No indicado' : s;
    final datos = Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.darkNavy, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: a?.nombreCompleto ?? 'A', size: 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a?.nombreCompleto ?? 'Apadrinado',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Expediente ${e.codigo ?? ''}', style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              _DatoBlanco(Icons.email_outlined, v(a?.correo)),
              _DatoBlanco(Icons.phone_outlined, v(a?.telefono)),
              _DatoBlanco(Icons.home_outlined, v(a?.direccion)),
              _DatoBlanco(Icons.cake_outlined,
                  a?.fechaNacimiento == null ? 'No indicada' : AppDateUtils.formatDate(a!.fechaNacimiento)),
              _DatoBlanco(Icons.location_city_outlined, v(a?.comunidadNombre)),
              _DatoBlanco(Icons.supervisor_account_outlined, 'Coordinador: ${v(a?.coordinadorNombre)}'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              _Contador('${e.totalActividades}', 'Actividades'),
              _Contador('${e.totalAprobadas}', 'Aprobadas'),
              _Contador('${e.totalDocumentos}', 'Documentos'),
              _Contador('${e.fotografias.length}', 'Fotografías'),
              _Contador('${e.cartas.length}', 'Cartas'),
            ],
          ),
        ],
      ),
    );

    final exportar = AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Exportar expediente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'El intervalo se aplica a la fecha de asignación de las actividades. '
            'El ZIP incluye solo las entregas aprobadas.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _elegirPeriodo,
            icon: const Icon(Icons.date_range),
            label: Text(_periodo == null
                ? 'Todo el historial'
                : '${AppDateUtils.formatShort(_periodo!.start.toIso8601String())} – '
                    '${AppDateUtils.formatShort(_periodo!.end.toIso8601String())}'),
          ),
          if (_periodo != null)
            TextButton(onPressed: () => setState(() => _periodo = null), child: const Text('Usar todo el historial')),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportando != null ? null : () => _exportar(true),
                  icon: _exportando == 'pdf' ? const _Cargando() : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Expediente PDF'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportando != null ? null : () => _exportar(false),
                  icon: _exportando == 'zip' ? const _Cargando() : const Icon(Icons.folder_zip_outlined),
                  label: const Text('Carpeta ZIP'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: datos),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: exportar),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [datos, const SizedBox(height: AppSpacing.md), exportar],
        );
      },
    );
  }

  /// Contenido de una pestaña centrado y con ancho limitado.
  Widget _lista(List<Widget> hijos, {Widget? encabezado}) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        ResponsiveContent(
          maxWidth: 900,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [if (encabezado != null) encabezado, ...hijos],
          ),
        ),
      ],
    );
  }

  Widget _tabActividades(Expediente e) {
    if (e.actividades.isEmpty) {
      return const EmptyState(icon: Icons.assignment_outlined, title: 'Sin actividades asignadas');
    }
    return _lista([
      for (final s in e.actividades)
        AsignacionCard(
          asignacion: s,
          onTap: s.actividad?.esTarea == true ? () => _abrirRevision(s.id) : null,
        ),
    ]);
  }

  Widget _tabDocumentos(Expediente e) => _DocumentosTab(documentos: e.documentos, lista: _lista);

  Widget _tabFotografias(Expediente e) {
    if (e.fotografias.isEmpty) {
      return const EmptyState(icon: Icons.photo_library_outlined, title: 'Sin fotografías');
    }
    return LayoutBuilder(builder: (context, c) {
      final columnas = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 600 ? 4 : 2);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnas,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.85,
            ),
            itemCount: e.fotografias.length,
            itemBuilder: (_, i) => _Miniatura(documento: e.fotografias[i]),
          ),
        ),
      );
    });
  }

  Widget _tabCartas(Expediente e) {
    if (e.cartas.isEmpty) {
      return const EmptyState(icon: Icons.mail_outline, title: 'Sin cartas');
    }
    return _lista([for (final c in e.cartas) _CartaTile(carta: c)]);
  }

  Widget _tabObservaciones(Expediente e) {
    return _lista(
      [
        if (e.observaciones.isEmpty)
          const EmptyState(icon: Icons.sticky_note_2_outlined, title: 'Sin observaciones')
        else
          for (final o in e.observaciones)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, color: AppColors.mustardGold),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.texto, style: const TextStyle(color: AppColors.charcoal)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          [
                            if (o.actividadTitulo != null) o.actividadTitulo!,
                            o.autorNombre ?? '',
                            AppDateUtils.formatDateTime(o.fecha),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline, color: AppColors.coralRed, size: 20),
                    onPressed: () => _eliminarObservacion(o),
                  ),
                ],
              ),
            ),
      ],
      encabezado: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _agregarObservacion,
            icon: const Icon(Icons.add),
            label: const Text('Agregar observación'),
          ),
        ),
      ),
    );
  }
}

class _DocumentosTab extends StatefulWidget {
  final List<Documento> documentos;
  final Widget Function(List<Widget> hijos, {Widget? encabezado}) lista;

  const _DocumentosTab({required this.documentos, required this.lista});

  @override
  State<_DocumentosTab> createState() => _DocumentosTabState();
}

class _DocumentosTabState extends State<_DocumentosTab> {
  String? _tipo;

  static const _etiquetas = {
    'DOCUMENTO': 'Documentos',
    'EVIDENCIA': 'Evidencias',
    'FORMULARIO': 'Formularios',
    'CARTA': 'Cartas',
    'OTRO': 'Otros',
  };

  Future<void> _descargar(Documento d) async {
    try {
      final msg = await DocumentoService().descargarYAbrir(d);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeDeError(e)), backgroundColor: AppColors.coralRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.documentos.isEmpty) {
      return const EmptyState(icon: Icons.folder_open_outlined, title: 'Sin documentos');
    }
    final tipos = widget.documentos.map((d) => d.tipoDocumento).toSet();
    final visibles = widget.documentos.where((d) => _tipo == null || d.tipoDocumento == _tipo).toList();
    return widget.lista(
      [
        for (final d in visibles)
          DocumentCard(
            documento: d,
            onTap: () => DocumentoViewerModal.mostrar(context, d),
            onDownload: () => _descargar(d),
          ),
      ],
      encabezado: tipos.length < 2
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilterChipWidget(label: 'Todos', selected: _tipo == null, onSelected: () => setState(() => _tipo = null)),
                  for (final t in tipos)
                    FilterChipWidget(
                      label: _etiquetas[t] ?? t,
                      selected: _tipo == t,
                      onSelected: () => setState(() => _tipo = t),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Miniatura extends StatefulWidget {
  final Documento documento;

  const _Miniatura({required this.documento});

  @override
  State<_Miniatura> createState() => _MiniaturaState();
}

class _MiniaturaState extends State<_Miniatura> {
  static final Map<int, Uint8List> _cache = {};
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    final id = widget.documento.id;
    _bytes = _cache.containsKey(id)
        ? Future.value(_cache[id])
        : DocumentoService().descargar(widget.documento).then((b) => _cache[id] = b);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.documento;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => DocumentoViewerModal.mostrar(context, d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                color: AppColors.surfaceVariant,
                child: FutureBuilder<Uint8List>(
                  future: _bytes,
                  builder: (_, snap) {
                    if (snap.hasData) {
                      return Image.memory(snap.data!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
                    }
                    if (snap.hasError) return const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary);
                    return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(d.actividadTitulo ?? d.nombreOriginal,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          Text(AppDateUtils.formatDate(d.fechaSubida),
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _CartaTile extends StatelessWidget {
  final Carta carta;

  const _CartaTile({required this.carta});

  @override
  Widget build(BuildContext context) {
    final c = carta;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.mail_outline, color: AppColors.tealCyan),
          title: Text(c.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              if (c.actividadTitulo != null) c.actividadTitulo!,
              if (c.version != null) 'versión ${c.version}',
              AppDateUtils.formatDate(c.fechaCreacion),
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [SelectableText(c.contenido, style: const TextStyle(height: 1.4))],
        ),
      ),
    );
  }
}

class _DatoBlanco extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _DatoBlanco(this.icon, this.texto);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withAlpha(200)),
        const SizedBox(width: 6),
        Flexible(child: Text(texto, style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 13))),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  final String valor;
  final String etiqueta;

  const _Contador(this.valor, this.etiqueta);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valor, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(etiqueta, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabsDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabsDelegate oldDelegate) => oldDelegate.tabBar != tabBar;
}
