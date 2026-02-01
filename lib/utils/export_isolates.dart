import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // Needed for PdfPageFormat

/// Top-level function to generate a multi-page PDF in an isolate.
Future<Uint8List> generatePdfIsolate(List<Uint8List> imagePages) async {
  final pdf = pw.Document();

    for (final imageBytes in imagePages) {
      final image = pw.MemoryImage(imageBytes);
  
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4, // Portrait A4 size
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image),
            );
          },
        ),
      );
    }  return await pdf.save();
}

/// Top-level function to generate a ZIP archive in an isolate.
Future<Uint8List?> generateZipIsolate(Map<String, Uint8List> images) async {
  final archive = Archive();
  for (final entry in images.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
