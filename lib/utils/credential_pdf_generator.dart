import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CredentialPdfGenerator {
  /// Genera un PDF con las imágenes de credenciales proporcionadas.
  /// Organiza las credenciales en una grilla de 2 columnas por 4 filas (8 por página).
  static Future<Uint8List> generatePdf(List<Uint8List> images) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        build: (pw.Context context) {
          return [
            pw.Wrap(
              spacing: 10, // Espacio horizontal entre credenciales
              runSpacing: 15, // Espacio vertical entre filas
              alignment: pw.WrapAlignment.center,
              children: images.map((imageBytes) {
                // Ancho carta aprox 612 puntos. Margen 30. Ancho util 582.
                // Mitad = 291.
                // Credencial ratio ~1.6. Ancho ~280pts va bien.
                return pw.Container(
                  width: 280, 
                  height: 176, // 280 / 1.59
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey200, width: 0.5), // Guía de corte sutil
                  ),
                  child: pw.Image(
                    pw.MemoryImage(imageBytes),
                    fit: pw.BoxFit.contain,
                  ),
                );
              }).toList(),
            )
          ];
        },
      ),
    );

    return pdf.save();
  }
}
