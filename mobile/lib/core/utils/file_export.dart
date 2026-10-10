import 'dart:typed_data';

import 'file_export_io.dart'
    if (dart.library.js_interop) 'file_export_web.dart' as impl;

/// Guarda un archivo descargado del backend (PDF, ZIP) y lo abre.
///
/// - Android / escritorio: lo guarda en la carpeta de la app y lo abre
///   con la aplicación del sistema (visor de PDF, gestor de archivos).
/// - Web: dispara la descarga del navegador.
///
/// Devuelve un mensaje listo para mostrar al usuario.
Future<String> guardarYAbrirArchivo(
  Uint8List bytes, {
  required String nombre,
  required String mimeType,
}) =>
    impl.guardarYAbrirArchivo(bytes, nombre: nombre, mimeType: mimeType);
