import 'dart:typed_data';
import '../shared/models/documento.dart';
import '../core/network/api_client.dart';

class DocumentoService {
  final ApiService _api = ApiService();

  Future<Documento> subirDocumento({
    required List<int> fileBytes,
    required String filename,
    int? apadrinadoId,
    int? expedienteId,
    int? actividadId,
    String? tipoDocumento,
    String? descripcion,
    int? usuarioId,
  }) async {
    final fields = <String, String>{};
    if (apadrinadoId != null) fields['apadrinadoId'] = apadrinadoId.toString();
    if (expedienteId != null) fields['expedienteId'] = expedienteId.toString();
    if (actividadId != null) fields['actividadId'] = actividadId.toString();
    if (tipoDocumento != null) fields['tipoDocumento'] = tipoDocumento;
    if (descripcion != null) fields['descripcion'] = descripcion;
    if (usuarioId != null) fields['usuarioId'] = usuarioId.toString();

    final response = await _api.uploadMultipart(
      endpoint: '/api/documentos/upload',
      fileBytes: fileBytes,
      filename: filename,
      fields: fields,
    );

    return Documento.fromJson(response);
  }

  Future<List<Documento>> listarPorExpediente(int expedienteId, {String? tipo}) async {
    String endpoint = '/api/documentos/expediente/$expedienteId';
    if (tipo != null && tipo.isNotEmpty) {
      endpoint += '?tipo=$tipo';
    }
    final response = await _api.get(endpoint);
    if (response is List) {
      return response.map((d) => Documento.fromJson(d)).toList();
    }
    return [];
  }

  Future<List<Documento>> listarPorActividad(int actividadId) async {
    final response = await _api.get('/api/documentos/actividad/$actividadId');
    if (response is List) {
      return response.map((d) => Documento.fromJson(d)).toList();
    }
    return [];
  }

  Future<Uint8List> descargarDocumento(int documentoId) async {
    return await _api.getBytes('/api/documentos/$documentoId/descargar');
  }

  Future<void> eliminar(int id) async {
    await _api.delete('/api/documentos/$id');
  }
}
