import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../core/utils/file_export.dart';
import '../shared/models/documento.dart';

/// Descarga de documentos (material del coordinador o archivos entregados).
class DocumentoService {
  final ApiService _api = ApiService();

  Future<Uint8List> descargar(Documento documento) =>
      _api.getBytes(documento.urlDescarga.isNotEmpty
          ? documento.urlDescarga
          : '/api/documentos/${documento.id}/descargar');

  /// Descarga el documento y lo guarda / abre en el dispositivo.
  Future<String> descargarYAbrir(Documento documento) async {
    final bytes = await descargar(documento);
    return guardarYAbrirArchivo(bytes,
        nombre: documento.nombreOriginal, mimeType: documento.tipoMime ?? 'application/octet-stream');
  }
}
