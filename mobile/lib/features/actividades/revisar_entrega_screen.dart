import 'package:flutter/material.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/documento.dart';
import '../../shared/models/historial_actividad.dart';
import '../../services/actividad_service.dart';
import '../../services/documento_service.dart';
import '../../../core/theme/app_theme.dart';
import '../documentos/documento_viewer_modal.dart';
import 'crear_actividad_screen.dart';

class RevisarEntregaScreen extends StatefulWidget {
  final Actividad actividad;

  const RevisarEntregaScreen({super.key, required this.actividad});

  @override
  State<RevisarEntregaScreen> createState() => _RevisarEntregaScreenState();
}

class _RevisarEntregaScreenState extends State<RevisarEntregaScreen> {
  final _actividadService = ActividadService();
  final _documentoService = DocumentoService();
  final _observacionesController = TextEditingController();

  List<Documento> _documentos = [];
  List<HistorialActividad> _historial = [];
  bool _isLoadingDocs = true;
  bool _isLoadingHistorial = true;
  bool _isSubmitting = false;
  late Actividad _actividad;

  @override
  void initState() {
    super.initState();
    _actividad = widget.actividad;
    _observacionesController.text = _actividad.observaciones ?? '';
    _cargarDocumentos();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarDocumentos() async {
    try {
      final docs = await _documentoService.listarPorActividad(_actividad.id);
      setState(() {
        _documentos = docs;
        _isLoadingDocs = false;
      });
    } catch (_) {
      setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _cargarHistorial() async {
    try {
      final h = await _actividadService.obtenerHistorialPorActividad(_actividad.id);
      setState(() {
        _historial = h;
        _isLoadingHistorial = false;
      });
    } catch (_) {
      setState(() => _isLoadingHistorial = false);
    }
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    final obs = _observacionesController.text.trim();

    if (nuevoEstado == 'CORRECCION_SOLICITADA' && obs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes indicar las observaciones para solicitar una corrección.'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final actualizada = await _actividadService.cambiarEstado(
        _actividad.id,
        nuevoEstado,
        observaciones: obs,
      );

      setState(() {
        _actividad = actualizada;
        _isSubmitting = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'APROBADA'
                ? '¡Actividad Aprobada con éxito!'
                : 'Se ha solicitado corrección al apadrinado.',
          ),
          backgroundColor: nuevoEstado == 'APROBADA' ? AppColors.sageGreen : AppColors.coralRed,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.coralRed,
        ),
      );
    }
  }

  Future<void> _editarActividad() async {
    final actualizada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearActividadScreen(actividadParaEditar: _actividad),
      ),
    );

    if (actualizada == true && mounted) {
      try {
        final act = await _actividadService.obtenerPorId(_actividad.id);
        setState(() {
          _actividad = act;
          _observacionesController.text = act.observaciones ?? '';
        });
        _cargarHistorial();
      } catch (_) {}
    }
  }

  Future<void> _eliminarActividad() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.coralRed),
            SizedBox(width: 8),
            Text('Eliminar Actividad'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la actividad "${_actividad.titulo}"?\n\nEsta acción no se puede deshacer y eliminará las evidencias entregadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar Permanentemente'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      setState(() => _isSubmitting = true);
      try {
        await _actividadService.eliminar(_actividad.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Actividad eliminada correctamente.'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar actividad: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = AppTheme.getEstadoColor(_actividad.estado);
    final estadoTexto = AppTheme.getEstadoTexto(_actividad.estado);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de Entrega'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Opciones de actividad',
            onSelected: (val) {
              if (val == 'editar') {
                _editarActividad();
              } else if (val == 'eliminar') {
                _eliminarActividad();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'editar',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: AppColors.darkNavy, size: 20),
                    SizedBox(width: 10),
                    Text('Editar Actividad'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'eliminar',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.coralRed, size: 20),
                    SizedBox(width: 10),
                    Text('Eliminar Actividad', style: TextStyle(color: AppColors.coralRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _actividad.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: estadoColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: estadoColor),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      color: estadoColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_actividad.apadrinadoNombre != null)
              Text(
                'Beneficiario: ${_actividad.apadrinadoNombre}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            const Divider(height: 24),

            // Instrucciones originales
            const Text(
              'Instrucciones asignadas:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                (_actividad.descripcion != null && _actividad.descripcion!.isNotEmpty)
                    ? _actividad.descripcion!
                    : 'Sin descripción adicional.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),

            // Documentos y Evidencias subidas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Evidencias y Archivos Recibidos:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                ),
                Text(
                  '${_documentos.length} archivo(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoadingDocs)
              const Center(child: CircularProgressIndicator())
            else if (_documentos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Aún no se han adjuntado archivos para esta actividad.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _documentos.length,
                itemBuilder: (context, index) {
                  final doc = _documentos[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: doc.isImage
                            ? AppColors.coralRed.withAlpha(30)
                            : AppColors.tealCyan.withAlpha(30),
                        child: Icon(
                          doc.isImage ? Icons.image : Icons.picture_as_pdf,
                          color: doc.isImage ? AppColors.coralRed : AppColors.tealCyan,
                        ),
                      ),
                      title: Text(doc.nombreOriginal, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Tipo: ${doc.tipoDocumento} • ${(doc.tamanioBytes != null ? (doc.tamanioBytes! / 1024).toStringAsFixed(1) : 0)} KB',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.visibility_outlined, color: AppColors.darkNavy),
                      onTap: () {
                        DocumentoViewerModal.mostrar(context, doc);
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),
            // Observaciones del Coordinador
            const Text(
              'Observaciones y Retroalimentación:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _observacionesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Escribe comentarios u observaciones para el apadrinado...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Botones de acción
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.coralRed,
                        side: const BorderSide(color: AppColors.coralRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _cambiarEstado('CORRECCION_SOLICITADA'),
                      icon: const Icon(Icons.close),
                      label: const Text('Pedir Corrección'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sageGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _cambiarEstado('APROBADA'),
                      icon: const Icon(Icons.check),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 28),
            _buildHistorialWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: AppColors.darkNavy, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Bitácora y Trazabilidad de la Actividad:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
            ),
            const Spacer(),
            if (_isLoadingHistorial)
              const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Text('${_historial.length} evento(s)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 10),
        if (_historial.isEmpty && !_isLoadingHistorial)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No hay eventos previos registrados en la bitácora.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _historial.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final h = _historial[index];
                  final color = AppTheme.getEstadoColor(h.estadoNuevo);
                  final fechaStr = h.fechaHora != null
                      ? h.fechaHora!.replaceFirst('T', ' ').substring(0, h.fechaHora!.length >= 16 ? 16 : h.fechaHora!.length)
                      : '';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: color.withAlpha(30),
                        child: Icon(
                          h.accion.contains('APROB')
                              ? Icons.check
                              : h.accion.contains('CORREC')
                                  ? Icons.replay
                                  : h.accion.contains('ENTREGA')
                                      ? Icons.file_upload
                                      : Icons.flag,
                          size: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  h.accion,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                                ),
                                Text(fechaStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            if (h.modificadoPorNombre != null)
                              Text(
                                'Por: ${h.modificadoPorNombre} (${h.modificadoPorRol ?? "Usuario"})',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            if (h.observaciones != null && h.observaciones!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3.0),
                                child: Text(
                                  h.observaciones!,
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
