import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart'
    if (dart.library.html) 'package:asystem_cobacam/utils/web_downloader_web.dart';

class ScheduleExporter {
  
  Future<bool> exportToImage(ScreenshotController controller) async {
    try {
      final Uint8List? imageBytes = await controller.capture();
      if (imageBytes == null) return false;

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return false;
      }
      
      await Gal.putImageBytes(imageBytes);
      return true;
    } catch (e) {
      debugPrint('Error exporting to image: $e');
      return false;
    }
  }

  Future<bool> exportToPdf(ScreenshotController controller, String fileName) async {
    try {
      final Uint8List? imageBytes = await controller.capture(
        pixelRatio: 2.0, // Higher resolution for better PDF quality
      );
      if (imageBytes == null) return false;

      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image),
            );
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      
      // Use the universal downloader
      await WebDownloader.downloadFile(pdfBytes, '$fileName.pdf', 'application/pdf');
      
      return true;
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      return false;
    }
  }
}
