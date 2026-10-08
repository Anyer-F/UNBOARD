import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/auth_service.dart';
import '../../../services/documento_service.dart';
import '../../../services/expediente_service.dart';
import 'documento_viewer_modal.dart';

/// Gestión documental del Apadrinado (especificación §20, §21.12).
///
/// Los documentos se tratan como información gestionada:
/// nombre, tipo, tamaño, fecha, propietario y estado.
/// Permite visualizar, descargar y subir.
class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final _documentoService = DocumentoService();
  final _expedienteService = ExpedienteService();

  List<dynamic> _documentos = [];
  int? _expedienteId;
  bool _isLoading = true;
  String? _error;
  String _filtro = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.apadrinadoId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final expediente = await _expedienteService
          .obtenerPorApadrinadoId(user!.apadrinadoId!);
      final docs = await _documentoService
          .listarPorExpediente(expediente.id);

      if (mounted) {
        setState(() {
          _expedienteId = expediente.id;
          _documentos = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<dynamic> get _filtrados {
    switch (_filtro) {
      case 'PDF':
        return _documentos.where((d) => d.isPdf).toList();
      case 'IMAGENES':
        return _documentos.where((d) => d.isImage).toList();
      case 'CARTAS':
        return _documentos.where((d) => d.isCarta).toList();
      default:
        return _documentos;
    }
  }

  Future<void> _subirDocumento() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.apadrinadoId == null || _expedienteId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo determinar tu expediente'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    try {
      final resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (resultado == null || resultado.files.isEmpty) return;

      final archivo = resultado.files.first;
      if (archivo.bytes == null || archivo.path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer el archivo seleccionado'),
            backgroundColor: AppColors.coralRed,
          ),
        );
        return;
      }

      if (!mounted) return;
      final valido = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Subir documento'),
          content: Text(
            '¿Subir "${archivo.name}" a tu expediente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Subir'),
            ),
          ],
        ),
      );
      if (valido != true || !mounted) return;

      await _documentoService.subirDocumento(
        fileBytes: archivo.bytes!,
        filename: archivo.name,
        expedienteId: _expedienteId,
        apadrinadoId: user!.apadrinadoId,
        usuarioId: user.usuarioId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento subido correctamente')),
      );
      _cargarDocumentos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.coralRed,
        ),
      );
    }
  }

  Future<void> _descargar(dynamic documento) async {
    try {
      await DocumentoViewerModal.mostrar(context, documento);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.coralRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Documentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Subir documento',
            onPressed: _subirDocumento,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingState(message: 'Cargando documentos...')
          : _error != null && _documentos.isEmpty
              ? ErrorState(
                  title: 'No se pudieron cargar los documentos',
                  message: _error,
                  onRetry: _cargarDocumentos,
                )
              : Column(
                  children: [
                    // Filtros
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          for (final filtro in const [
                            'TODOS',
                            'PDF',
                            'IMAGENES',
                            'CARTAS'
                          ])
                            FilterChipWidget(
                              label: filtro == 'TODOS'
                                  ? 'Todos'
                                  : filtro == 'PDF'
                                      ? 'PDF'
                                      : filtro == 'IMAGENES'
                                          ? 'Fotografías'
                                          : 'Cartas',
                              selected: _filtro == filtro,
                              onSelected: () =>
                                  setState(() => _filtro = filtro),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _documentos.isEmpty
                          ? const EmptyState(
                              icon: Icons.description_outlined,
                              title: 'Sin documentos',
                              description:
                                  'Los documentos de tu expediente aparecerán aquí',
                              action: null,
                            )
                          : _filtrados.isEmpty
                              ? EmptyState(
                                  icon: Icons.filter_list_off,
                                  title: 'Sin resultados',
                                  description:
                                      'No hay documentos con este filtro',
                                  action: SecondaryButton(
                                    label: 'Ver todos',
                                    expanded: false,
                                    onPressed: () =>
                                        setState(() => _filtro = 'TODOS'),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _cargarDocumentos,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    itemCount: _filtrados.length,
                                    itemBuilder: (context, index) {
                                      final doc = _filtrados[index];
                                      return DocumentCard(
                                        documento: doc,
                                        onTap: () =>
                                            _descargar(doc),
                                        onDownload: () =>
                                            _descargar(doc),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
    );
  }
}
