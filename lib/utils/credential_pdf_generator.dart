import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CredentialPdfGenerator {
  /// Genera un PDF con las imágenes de credenciales proporcionadas.
  /// Organiza las credenciales en una grilla de 2 columnas por 5 filas (10 por página).
  static Future<Uint8List> generatePdf(List<Uint8List> images) async {
    final pdf = pw.Document();

    // Tamaño Carta: 612 x 792 puntos
    // Margen vertical total: 20 (10 arriba + 10 abajo) -> Espacio útil alto: 772
    // Espacio entre filas: 5 * 4 espacios = 20 pts
    // Altura disponible para 5 credenciales: 772 - 20 = 752.
    // Altura por credencial: 752 / 5 = 150.4 puntos.
    
    // Ancho útil: 612 - 30 (márgenes) = 582
    // Ancho por columna: 582 / 2 = 291 (menos espacio intermedio) -> ~280 ancho.
    
    // Ratio credencial estándar (8.5cm x 5.5cm) = 1.54
    // 280 / 150 = 1.86. Cabe perfectamente con margen interno.

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        build: (pw.Context context) {
          return [
            pw.Wrap(
              spacing: 10, // Espacio horizontal
              runSpacing: 10, // Espacio vertical
              alignment: pw.WrapAlignment.center,
              children: images.map((imageBytes) {
                return pw.Container(
                  width: 280, 
                  height: 150, // Altura optimizada para 5 filas
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Center( // Centrar imagen si el ratio no es exacto
                    child: pw.Image(
                      pw.MemoryImage(imageBytes),
                      fit: pw.BoxFit.contain,
                    ),
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
