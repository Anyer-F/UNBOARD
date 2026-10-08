import 'package:flutter/material.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/documento.dart';
import '../../services/documento_service.dart';
import '../../../core/theme/app_theme.dart';
import '../documentos/documento_viewer_modal.dart';

class ActividadDetalleScreen extends StatefulWidget {
  final Actividad actividad;

  const ActividadDetalleScreen({super.key, required this.actividad});

  @override
  State<ActividadDetalleScreen> createState() => _ActividadDetalleScreenState();
}

class _ActividadDetalleScreenState extends State<ActividadDetalleScreen> {
  final _documentoService = DocumentoService();

  List<Documento> _documentos = [];
  bool _isLoadingDocs = true;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    try {
      final docs = await _documentoService.listarPorActividad(widget.actividad.id);
      setState(() {
        _documentos = docs;
        _isLoadingDocs = false;
      });
    } catch (_) {
      setState(() => _isLoadingDocs = false);
    }
  }

  Color _getEstadoColor(String? estado) {
    switch (estado?.toUpperCase()) {
      case 'PENDIENTE':
        return AppColors.mustardGold;
      case 'EN_PROCESO':
        return AppColors.tealCyan;
      case 'ENTREGADA':
        return AppColors.darkNavy;
      case 'APROBADA':
        return AppColors.sageGreen;
      case 'CORRECCION_SOLICITADA':
        return AppColors.coralRed;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoTexto(String? estado) {
    switch (estado?.toUpperCase()) {
      case 'PENDIENTE':
        return 'Pendiente';
      case 'EN_PROCESO':
        return 'En Proceso';
      case 'ENTREGADA':
        return 'Entregada';
      case 'APROBADA':
        return 'Aprobada';
      case 'CORRECCION_SOLICITADA':
        return 'Corrección Solicitada';
      default:
        return estado ?? 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = _getEstadoColor(widget.actividad.estado);
    final estadoTexto = _getEstadoTexto(widget.actividad.estado);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.actividad.titulo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: estadoColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: estadoColor),
              ),
              child: Text(
                estadoTexto,
                style: TextStyle(
                  color: estadoColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            const Text(
              'Título',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.actividad.titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 16),

            // Descripción
            const Text(
              'Descripción',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                widget.actividad.descripcion ?? 'Sin descripción',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            // Fechas
            Row(
              children: [
                Expanded(
                  child: _buildInfoBox(
                    icon: Icons.calendar_today,
                    label: 'Fecha de creación',
                    value: widget.actividad.fechaCreacion ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoBox(
                    icon: Icons.event,
                    label: 'Fecha límite',
                    value: widget.actividad.fechaLimite ?? 'N/A',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Requisitos
            const Text(
              'Requisitos',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildRequisito(
                    icon: Icons.camera_alt,
                    label: 'Fotografía requerida',
                    cumple: widget.actividad.requiereFotografia,
                  ),
                  const Divider(),
                  _buildRequisito(
                    icon: Icons.description,
                    label: 'Documento requerido',
                    cumple: widget.actividad.requiereDocumento,
                  ),
                ],
              ),
            ),

            // Observaciones
            if (widget.actividad.observaciones != null &&
                widget.actividad.observaciones!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Observaciones',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mustardGold.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mustardGold.withAlpha(50)),
                ),
                child: Text(
                  widget.actividad.observaciones!,
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Documentos entregados
            const Text(
              'Documentos entregados',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),

            if (_isLoadingDocs)
              const Center(child: CircularProgressIndicator())
            else if (_documentos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.folder_open, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No hay documentos entregados aún',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ..._documentos.map((doc) => _buildDocumentoCard(doc)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.tealCyan),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequisito({
    required IconData icon,
    required String label,
    required bool? cumple,
  }) {
    final activo = cumple == true;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: activo ? AppColors.tealCyan : Colors.grey,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: activo ? AppColors.charcoal : Colors.grey,
            ),
          ),
        ),
        Icon(
          activo ? Icons.check_circle : Icons.remove_circle,
          size: 20,
          color: activo ? AppColors.sageGreen : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildDocumentoCard(Documento doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListTile(
        leading: Icon(
          doc.isImage ? Icons.image : Icons.picture_as_pdf,
          color: AppColors.darkNavy,
        ),
        title: Text(
          doc.nombreOriginal,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${doc.tipoDocumento} • ${(doc.tamanioBytes != null ? (doc.tamanioBytes! / 1024).toStringAsFixed(1) : 0)} KB',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.visibility_outlined, size: 20),
        onTap: () => DocumentoViewerModal.mostrar(context, doc),
      ),
    );
  }
}
