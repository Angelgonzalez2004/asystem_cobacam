import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // Needed for PdfPageFormat

/// Top-level function to generate a multi-page PDF in an isolate.
Future<Uint8List> generatePdfIsolate(List<Uint8List> imagePages) async {
  final pdf = pw.Document();

  for (int i = 0; i < imagePages.length; i += 2) {
    final image1 = pw.MemoryImage(imagePages[i]);
    pw.MemoryImage? image2;
    if (i + 1 < imagePages.length) {
      image2 = pw.MemoryImage(imagePages[i+1]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          if (image2 != null) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Image(image1)),
                pw.SizedBox(width: 10),
                pw.Expanded(child: pw.Image(image2)),
              ],
            );
          } else {
            return pw.Center(
              child: pw.Image(image1),
            );
          }
        },
      ),
    );
  }
  return await pdf.save();
}

/// Top-level function to generate a ZIP archive in an isolate.
Future<Uint8List?> generateZipIsolate(Map<String, Uint8List> images) async {
  final archive = Archive();
  for (final entry in images.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
