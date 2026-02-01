import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Necesario para kIsWeb y debugPrint
import 'package:path_provider/path_provider.dart'; // Para ubicaciones de guardado por defecto en móvil

class WebDownloader {
  static Future<void> downloadFile(
      Uint8List bytes, String fileName, String mimeType) async {
    try {
      String? directoryPath;
      if (Platform.isAndroid || Platform.isIOS) {
        // En móvil, es más común guardar directamente en una carpeta pública
        // o usar un selector que guarde en la carpeta de descargas de la app.
        // FilePicker.platform.getDirectoryPath() puede ser confuso en móvil.
        // Por ahora, guardaremos en la carpeta de descargas para una mejor experiencia.
        final directory = await getDownloadsDirectory();
        directoryPath = directory?.path;
      } else {
        // En escritorio (Windows, macOS, Linux), pedimos al usuario que elija una carpeta.
        directoryPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Por favor, selecciona una carpeta para guardar',
        );
      }


      if (directoryPath != null) {
        final String filePath = '$directoryPath/$fileName';
        final File file = File(filePath);
        await file.writeAsBytes(bytes);
        
        debugPrint('Archivo guardado exitosamente en: $filePath');
        // Aquí se podría mostrar una notificación al usuario, pero por ahora solo imprimimos en consola.
      } else {
        // El usuario canceló la selección de carpeta
        debugPrint('El usuario canceló la descarga.');
      }
    } catch (e) {
      debugPrint('Error al guardar el archivo: $e');
      // Sería bueno mostrar un error al usuario.
    }
  }
}