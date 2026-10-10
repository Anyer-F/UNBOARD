import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String> guardarYAbrirArchivo(
  Uint8List bytes, {
  required String nombre,
  required String mimeType,
}) async {
  Directory? dir;
  if (Platform.isAndroid) {
    // Android/data/<paquete>/files: accesible desde el gestor de archivos
    dir = await getExternalStorageDirectory();
  }
  dir ??= await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/$nombre');
  await file.writeAsBytes(bytes, flush: true);

  final kb = (bytes.length / 1024).toStringAsFixed(1);
  final resultado = await OpenFilex.open(file.path, type: mimeType);
  if (resultado.type == ResultType.done) {
    return '$nombre guardado ($kb KB)';
  }
  if (resultado.type == ResultType.noAppToOpen) {
    return '$nombre guardado en ${file.path}. '
        'No hay una aplicación instalada para abrirlo.';
  }
  return '$nombre guardado en ${file.path}';
}
