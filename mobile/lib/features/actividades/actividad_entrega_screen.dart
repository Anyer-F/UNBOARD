import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/documento.dart';
import '../../services/auth_service.dart';
import '../../services/documento_service.dart';
import '../../../core/theme/app_theme.dart';
import '../documentos/documento_viewer_modal.dart';

class ActividadEntregaScreen extends StatefulWidget {
  final Actividad actividad;
  final bool soloDocumentos;

  const ActividadEntregaScreen({
    super.key,
    required this.actividad,
    this.soloDocumentos = false,
  });

  @override
  State<ActividadEntregaScreen> createState() => _ActividadEntregaScreenState();
}

class _ActividadEntregaScreenState extends State<ActividadEntregaScreen> {
  final _documentoService = DocumentoService();
  final _picker = ImagePicker();

  final _cartaController = TextEditingController();
  final _descripcionController = TextEditingController();

  Uint8List? _fotoBytes;
  String? _fotoNombre;

  Uint8List? _archivoBytes;
  String? _archivoNombre;

  List<Documento> _documentosExistentes = [];
  bool _isLoadingDocs = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cargarDocumentosExistentes();
  }

  @override
  void dispose() {
    _cartaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _cargarDocumentosExistentes() async {
    try {
      final docs = await _documentoService.listarPorActividad(widget.actividad.id);
      setState(() {
        _documentosExistentes = docs;
        _isLoadingDocs = false;
      });
    } catch (_) {
      setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _tomarFoto(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        setState(() {
          _fotoBytes = bytes;
          _fotoNombre = xFile.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar imagen: $e')),
      );
    }
  }

  Future<void> _seleccionarDocumento() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _archivoBytes = file.bytes;
            _archivoNombre = file.name;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar archivo: $e')),
      );
    }
  }

  Future<void> _enviarEntrega() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final apadrinadoId = user?.apadrinadoId ?? widget.actividad.apadrinadoId;

    if (_fotoBytes == null && _archivoBytes == null && _cartaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor adjunta una foto, un documento o escribe tu carta antes de enviar.'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Si escribió carta en texto, enviarla como archivo de texto/carta
      if (_cartaController.text.trim().isNotEmpty) {
        final cartaBytes = Uint8List.fromList(_cartaController.text.trim().codeUnits);
        await _documentoService.subirDocumento(
          fileBytes: cartaBytes,
          filename: 'carta_${DateTime.now().millisecondsSinceEpoch}.txt',
          apadrinadoId: apadrinadoId,
          actividadId: widget.actividad.id,
          tipoDocumento: 'CARTA',
          descripcion: _descripcionController.text.trim().isNotEmpty
              ? _descripcionController.text.trim()
              : 'Carta redactada por el apadrinado',
          usuarioId: user?.usuarioId,
        );
      }

      // 2. Si tomó/adjuntó fotografía
      if (_fotoBytes != null) {
        await _documentoService.subirDocumento(
          fileBytes: _fotoBytes!,
          filename: _fotoNombre ?? 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
          apadrinadoId: apadrinadoId,
          actividadId: widget.actividad.id,
          tipoDocumento: 'FOTOGRAFIA',
          descripcion: _descripcionController.text.trim(),
          usuarioId: user?.usuarioId,
        );
      }

      // 3. Si adjuntó archivo/PDF
      if (_archivoBytes != null) {
        await _documentoService.subirDocumento(
          fileBytes: _archivoBytes!,
          filename: _archivoNombre ?? 'evidencia_${DateTime.now().millisecondsSinceEpoch}.pdf',
          apadrinadoId: apadrinadoId,
          actividadId: widget.actividad.id,
          tipoDocumento: 'EVIDENCIA',
          descripcion: _descripcionController.text.trim(),
          usuarioId: user?.usuarioId,
        );
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Tu entrega ha sido enviada con éxito al coordinador!'),
          backgroundColor: AppColors.sageGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar entrega: $e'),
          backgroundColor: AppColors.coralRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = AppTheme.getEstadoColor(widget.actividad.estado);
    final estadoTexto = AppTheme.getEstadoTexto(widget.actividad.estado);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Entrega'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la actividad
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.actividad.titulo,
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
            Text(
              'Fecha límite: ${widget.actividad.fechaLimite ?? "Sin fecha"}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            // Instrucciones del coordinador
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instrucciones de tu coordinador:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.actividad.descripcion ?? 'Por favor sigue las indicaciones institucionales.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  if (widget.actividad.observaciones != null && widget.actividad.observaciones!.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text(
                      'Observaciones previas: ${widget.actividad.observaciones}',
                      style: const TextStyle(fontSize: 12, color: AppColors.coralRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isLoadingDocs && _documentosExistentes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Archivos entregados anteriormente para esta actividad:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
              ),
              const SizedBox(height: 6),
              ..._documentosExistentes.map((doc) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(doc.isImage ? Icons.image : Icons.picture_as_pdf, color: AppColors.darkNavy),
                      title: Text(doc.nombreOriginal, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${doc.tipoDocumento} • ${(doc.tamanioBytes != null ? (doc.tamanioBytes! / 1024).toStringAsFixed(1) : 0)} KB'),
                      trailing: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.darkNavy),
                      onTap: () => DocumentoViewerModal.mostrar(context, doc),
                    ),
                  )),
            ],
            const SizedBox(height: 24),

            // Sección 1: Redacción de Carta (si aplica)
            const Text(
              '1. Escribir carta en línea (opcional):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cartaController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Querido padrino, te escribo para contarte sobre mis avances escolares...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // Sección 2: Fotografía de evidencia
            const Text(
              '2. Adjuntar Fotografía:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _tomarFoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: AppColors.coralRed),
                    label: const Text('Tomar Foto'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _tomarFoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, color: AppColors.tealCyan),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            if (_fotoNombre != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.check, color: Colors.green, size: 18),
                label: Text('Foto seleccionada: $_fotoNombre', overflow: TextOverflow.ellipsis),
                onDeleted: () => setState(() {
                  _fotoBytes = null;
                  _fotoNombre = null;
                }),
              ),
            ],

            const SizedBox(height: 20),

            // Sección 3: Adjuntar archivo / PDF
            const Text(
              '3. Adjuntar Archivo o PDF (Formulario, Calificaciones, etc.):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: _seleccionarDocumento,
              icon: const Icon(Icons.attach_file, color: AppColors.darkNavy),
              label: const Text('Seleccionar archivo del dispositivo'),
            ),
            if (_archivoNombre != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.check, color: Colors.green, size: 18),
                label: Text('Archivo: $_archivoNombre', overflow: TextOverflow.ellipsis),
                onDeleted: () => setState(() {
                  _archivoBytes = null;
                  _archivoNombre = null;
                }),
              ),
            ],

            const SizedBox(height: 20),

            // Comentario adicional
            const Text(
              'Mensaje o nota para el coordinador (opcional):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkNavy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                hintText: 'Ej: Envío mi carta y las fotos de mis actividades escolares.',
              ),
            ),

            const SizedBox(height: 30),

            // Botón de Envío
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
                onPressed: _isSubmitting ? null : _enviarEntrega,
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.send_rounded),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar Entrega al Coordinador'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
