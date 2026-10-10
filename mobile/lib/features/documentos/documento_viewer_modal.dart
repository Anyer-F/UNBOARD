import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../shared/models/documento.dart';
import '../../core/utils/file_export.dart';
import '../../services/documento_service.dart';
import '../../../core/theme/app_theme.dart';

class DocumentoViewerModal extends StatefulWidget {
  final Documento documento;

  const DocumentoViewerModal({super.key, required this.documento});

  static Future<void> mostrar(BuildContext context, Documento documento) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DocumentoViewerModal(documento: documento),
    );
  }

  @override
  State<DocumentoViewerModal> createState() => _DocumentoViewerModalState();
}

class _DocumentoViewerModalState extends State<DocumentoViewerModal> {
  final _docService = DocumentoService();

  Uint8List? _bytes;
  String? _textoCarta;
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarContenido();
  }

  Future<void> _cargarContenido() async {
    try {
      final bytes = await _docService.descargarDocumento(widget.documento.id);
      String? carta;
      if (widget.documento.isText) {
        try {
          carta = utf8.decode(bytes);
        } catch (_) {
          carta = latin1.decode(bytes);
        }
      }

      if (mounted) {
        setState(() {
          _bytes = bytes;
          _textoCarta = carta;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// Abre el documento con la aplicación del sistema (o lo descarga en
  /// web). Usa los bytes ya descargados con el token de sesión: abrir la
  /// URL directamente en un navegador externo fallaría sin autenticación.
  Future<void> _abrirEnNavegadorOVisor() => _guardarEnDispositivo();

  Future<void> _guardarEnDispositivo() async {
    setState(() => _isSaving = true);

    try {
      final bytes =
          _bytes ?? await _docService.descargarDocumento(widget.documento.id);
      final cleanName = widget.documento.nombreOriginal
          .replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final mensaje = await guardarYAbrirArchivo(
        bytes,
        nombre: cleanName,
        mimeType: widget.documento.tipoMime ?? 'application/octet-stream',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: AppColors.sageGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar archivo: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documento;
    final sizeKb = (doc.tamanioBytes != null) ? (doc.tamanioBytes! / 1024).toStringAsFixed(1) : '-';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 650),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de Título
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                color: AppColors.darkNavy,
                child: Row(
                  children: [
                    Icon(
                      doc.isImage
                          ? Icons.image
                          : doc.isCarta
                              ? Icons.mail
                              : Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.nombreOriginal,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${doc.tipoDocumento} • $sizeKb KB',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),

              // Contenido Principal
              Flexible(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(50.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.coralRed, size: 48),
                                const SizedBox(height: 12),
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  onPressed: _abrirEnNavegadorOVisor,
                                  child: const Text('Intentar abrir mediante enlace'),
                                ),
                              ],
                            ),
                          )
                        : _buildContenido(),
              ),

              // Barra de Acciones Inferior
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.lightBg,
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    if (doc.descripcion != null && doc.descripcion!.isNotEmpty)
                      Expanded(
                        child: Text(
                          'Nota: ${doc.descripcion}',
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _abrirEnNavegadorOVisor,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Abrir', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealCyan,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _isSaving ? null : _guardarEnDispositivo,
                      icon: _isSaving
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.download, size: 16),
                      label: const Text('Guardar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (widget.documento.isImage && _bytes != null) {
      return Container(
        color: Colors.black87,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              _bytes!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('No se pudo decodificar la imagen', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      );
    }

    if (_textoCarta != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E0C8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.mail_outline, color: AppColors.coralRed, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Carta del Apadrinado',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                  ),
                ],
              ),
              const Divider(height: 20),
              SelectableText(
                _textoCarta!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Para archivos PDF u otros documentos
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.tealCyan.withAlpha(25),
            child: Icon(
              widget.documento.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              color: AppColors.tealCyan,
              size: 45,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.documento.nombreOriginal,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tipo: ${widget.documento.tipoDocumento} (${widget.documento.tipoMime ?? "Archivo"})',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
            onPressed: _abrirEnNavegadorOVisor,
            icon: const Icon(Icons.remove_red_eye),
            label: const Text('Ver / Descargar en Visor Externo'),
          ),
        ],
      ),
    );
  }
}
