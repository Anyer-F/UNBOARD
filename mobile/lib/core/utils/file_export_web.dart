import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> guardarYAbrirArchivo(
  Uint8List bytes, {
  required String nombre,
  required String mimeType,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre;
  web.document.body!.append(enlace);
  enlace.click();
  enlace.remove();
  // Se libera la URL después de que el navegador inicia la descarga
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));

  final kb = (bytes.length / 1024).toStringAsFixed(1);
  return '$nombre descargado ($kb KB)';
}
