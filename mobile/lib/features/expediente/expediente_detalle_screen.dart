import 'package:flutter/material.dart';
import '../../core/utils/file_export.dart';
import '../../shared/models/documento.dart';
import '../../shared/models/expediente.dart';
import '../../shared/models/historial_actividad.dart';
import '../../services/actividad_service.dart';
import '../../services/expediente_service.dart';
import '../../../core/theme/app_theme.dart';
import '../actividades/revisar_entrega_screen.dart';
import '../documentos/documento_viewer_modal.dart';

class ExpedienteDetalleScreen extends StatefulWidget {
  final int? expedienteId;
  final int? apadrinadoId;

  const ExpedienteDetalleScreen({
    super.key,
    this.expedienteId,
    this.apadrinadoId,
  });

  @override
  State<ExpedienteDetalleScreen> createState() => _ExpedienteDetalleScreenState();
}

class _ExpedienteDetalleScreenState extends State<ExpedienteDetalleScreen> with SingleTickerProviderStateMixin {
  final _expedienteService = ExpedienteService();
  final _actividadService = ActividadService();

  late TabController _tabController;

  Expediente? _expediente;
  List<HistorialActividad> _historial = [];
  bool _isLoading = true;
  String? _error;
  bool _isDownloadingPdf = false;
  bool _isDownloadingZip = false;
  DateTimeRange? _periodo;

  String _filtroTipo = 'TODOS';
  final _searchDocController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarExpediente();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchDocController.dispose();
    super.dispose();
  }

  Future<void> _cargarExpediente() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Expediente exp;
      if (widget.expedienteId != null) {
        exp = await _expedienteService.obtenerPorId(widget.expedienteId!);
      } else if (widget.apadrinadoId != null) {
        exp = await _expedienteService.obtenerPorApadrinadoId(widget.apadrinadoId!);
      } else {
        throw Exception('No se especificó un identificador de expediente válido.');
      }

      // Cargar historial del apadrinado
      List<HistorialActividad> hist = [];
      final apadId = exp.apadrinado?.id ?? widget.apadrinadoId;
      if (apadId != null) {
        try {
          hist = await _actividadService.obtenerHistorialPorApadrinado(apadId);
        } catch (_) {}
      }

      setState(() {
        _expediente = exp;
        _historial = hist;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Elige el período del expediente a exportar. Sin período se
  /// exporta el expediente completo.
  Future<void> _elegirPeriodo() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(ahora.year, ahora.month, ahora.day),
      initialDateRange: _periodo,
      helpText: 'Período del expediente',
      saveText: 'Aplicar',
      cancelText: 'Cancelar',
      fieldStartLabelText: 'Desde',
      fieldEndLabelText: 'Hasta',
    );
    if (rango != null && mounted) setState(() => _periodo = rango);
  }

  String get _textoPeriodo {
    if (_periodo == null) return 'Todo el expediente';
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${f(_periodo!.start)} - ${f(_periodo!.end)}';
  }

  Future<void> _exportar({required bool zip}) async {
    if (_expediente == null) return;
    setState(() => zip ? _isDownloadingZip = true : _isDownloadingPdf = true);

    try {
      final id = _expediente!.id;
      final bytes = zip
          ? await _expedienteService.descargarZip(id,
              desde: _periodo?.start, hasta: _periodo?.end)
          : await _expedienteService.descargarPdf(id,
              desde: _periodo?.start, hasta: _periodo?.end);

      final mensaje = await guardarYAbrirArchivo(
        bytes,
        nombre: zip ? 'Expediente_Organizado_$id.zip' : 'Expediente_$id.pdf',
        mimeType: zip ? 'application/zip' : 'application/pdf',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: zip ? AppColors.tealCyan : AppColors.sageGreen,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error al generar el ${zip ? 'ZIP' : 'PDF'}: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.coralRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => zip ? _isDownloadingZip = false : _isDownloadingPdf = false);
      }
    }
  }

  List<Documento> get _documentosFiltrados {
    if (_expediente == null) return [];
    var docs = _expediente!.documentos;

    if (_filtroTipo != 'TODOS') {
      docs = docs.where((d) => d.tipoDocumento.toUpperCase() == _filtroTipo).toList();
    }

    final query = _searchDocController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      docs = docs.where((d) {
        final nombre = d.nombreOriginal.toLowerCase();
        final desc = d.descripcion?.toLowerCase() ?? '';
        final act = d.actividadTitulo?.toLowerCase() ?? '';
        return nombre.contains(query) || desc.contains(query) || act.contains(query);
      }).toList();
    }

    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expediente Digital'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: AppColors.coralRed),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarExpediente,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _expediente == null
                  ? const Center(child: Text('Expediente no disponible.'))
                  : Column(
                      children: [
                        // Tarjeta de Cabecera del Beneficiario
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.darkNavy,
                                    child: const Icon(Icons.person, size: 34, color: Colors.white),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _expediente!.apadrinado?.nombre ?? 'Beneficiario',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Comunidad: ${_expediente!.apadrinado?.comunidadNombre ?? "No asignada"}',
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          'Coordinador: ${_expediente!.apadrinado?.coordinadorNombre ?? "No asignado"}',
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.sageGreen.withAlpha(25),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.sageGreen),
                                    ),
                                    child: const Text(
                                      'ACTIVO',
                                      style: TextStyle(
                                        color: AppColors.sageGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Período del expediente a exportar
                              Material(
                                color: AppColors.darkNavy.withAlpha(10),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _elegirPeriodo,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.date_range, size: 18, color: AppColors.darkNavy),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Período: $_textoPeriodo',
                                            style: const TextStyle(fontSize: 13, color: AppColors.darkNavy),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_periodo != null)
                                          IconButton(
                                            tooltip: 'Exportar todo el expediente',
                                            icon: const Icon(Icons.close, size: 18),
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => setState(() => _periodo = null),
                                          )
                                        else
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 10),
                                            child: Text(
                                              'Cambiar',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.tealCyan,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Botones de Exportación Oficial
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.darkNavy,
                                        side: const BorderSide(color: AppColors.darkNavy, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: _isDownloadingPdf ? null : () => _exportar(zip: false),
                                      icon: _isDownloadingPdf
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('Exportar PDF', style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.tealCyan,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: _isDownloadingZip ? null : () => _exportar(zip: true),
                                      icon: _isDownloadingZip
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : const Icon(Icons.archive, size: 18),
                                      label: const Text('Descargar ZIP', style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Barra de Pestañas (3 Pestañas: Actividades, Documentos, Bitácora)
                        Container(
                          color: Colors.white,
                          child: TabBar(
                            controller: _tabController,
                            tabAlignment: TabAlignment.fill,
                            indicatorColor: AppColors.darkNavy,
                            labelColor: AppColors.darkNavy,
                            unselectedLabelColor: Colors.grey,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            tabs: [
                              Tab(text: 'Actividades (${_expediente!.actividades.length})'),
                              Tab(text: 'Documentos (${_expediente!.documentos.length})'),
                              Tab(text: 'Bitácora (${_historial.length})'),
                            ],
                          ),
                        ),

                        // Contenido de Pestañas
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Pestaña 1: Actividades
                              _buildActividadesTab(),

                              // Pestaña 2: Documentos con Filtro
                              _buildDocumentosTab(),

                              // Pestaña 3: Bitácora y Trazabilidad
                              _buildBitacoraTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildActividadesTab() {
    if (_expediente!.actividades.isEmpty) {
      return const Center(child: Text('No hay actividades en este expediente.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _expediente!.actividades.length,
      itemBuilder: (context, index) {
        final act = _expediente!.actividades[index];
        final color = AppTheme.getEstadoColor(act.estado);
        return Card(
          child: ListTile(
            title: Text(act.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(act.descripcion ?? 'Sin descripción', maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Fecha límite: ${act.fechaLimite ?? "N/A"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(
                AppTheme.getEstadoTexto(act.estado),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RevisarEntregaScreen(actividad: act)),
              );
              if (updated == true) _cargarExpediente();
            },
          ),
        );
      },
    );
  }

  Widget _buildDocumentosTab() {
    final docs = _documentosFiltrados;

    return Column(
      children: [
        // Buscador y Selector de Filtros
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchDocController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o actividad...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchDocController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchDocController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChipFiltro('TODOS', 'Todos (${_expediente!.documentos.length})'),
                    const SizedBox(width: 6),
                    _buildChipFiltro('CARTA', 'Cartas'),
                    const SizedBox(width: 6),
                    _buildChipFiltro('FOTOGRAFIA', 'Fotos'),
                    const SizedBox(width: 6),
                    _buildChipFiltro('FORMULARIO', 'Formularios'),
                    const SizedBox(width: 6),
                    _buildChipFiltro('EVIDENCIA', 'Evidencias'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista de Documentos
        Expanded(
          child: docs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _expediente!.documentos.isEmpty
                          ? 'No hay documentos subidos en este expediente.'
                          : 'No se encontraron documentos con el filtro aplicado.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: doc.isImage
                              ? AppColors.coralRed.withAlpha(25)
                              : doc.isCarta
                                  ? Colors.amber.withAlpha(35)
                                  : AppColors.tealCyan.withAlpha(25),
                          child: Icon(
                            doc.isImage
                                ? Icons.image
                                : doc.isCarta
                                    ? Icons.mail
                                    : Icons.picture_as_pdf,
                            color: doc.isImage
                                ? AppColors.coralRed
                                : doc.isCarta
                                    ? Colors.amber.shade900
                                    : AppColors.tealCyan,
                          ),
                        ),
                        title: Text(
                          doc.nombreOriginal,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${doc.tipoDocumento} • ${(doc.tamanioBytes != null ? (doc.tamanioBytes! / 1024).toStringAsFixed(1) : 0)} KB',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (doc.actividadTitulo != null)
                              Text(
                                'Actividad: ${doc.actividadTitulo}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.visibility_outlined, color: AppColors.darkNavy),
                        onTap: () {
                          DocumentoViewerModal.mostrar(context, doc);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChipFiltro(String tipo, String label) {
    final selected = _filtroTipo == tipo;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
      selectedColor: AppColors.darkNavy,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.charcoal),
      onSelected: (_) => setState(() => _filtroTipo = tipo),
    );
  }

  Widget _buildBitacoraTab() {
    if (_historial.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay registros de cambios en la bitácora de este apadrinado.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _historial.length,
      itemBuilder: (context, index) {
        final h = _historial[index];
        final color = AppTheme.getEstadoColor(h.estadoNuevo);
        final fechaStr = h.fechaHora != null
            ? h.fechaHora!.replaceFirst('T', ' ').substring(0, h.fechaHora!.length >= 16 ? 16 : h.fechaHora!.length)
            : '';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withAlpha(30),
                  child: Icon(
                    h.accion.contains('APROB')
                        ? Icons.check
                        : h.accion.contains('CORREC')
                            ? Icons.replay
                            : h.accion.contains('ENTREGA')
                                ? Icons.file_upload
                                : Icons.flag,
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              h.accion,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                          Text(fechaStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      if (h.actividadTitulo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'Actividad: ${h.actividadTitulo}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkNavy),
                          ),
                        ),
                      if (h.modificadoPorNombre != null)
                        Text(
                          'Responsable: ${h.modificadoPorNombre} (${h.modificadoPorRol ?? "Usuario"})',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      if (h.observaciones != null && h.observaciones!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              h.observaciones!,
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
