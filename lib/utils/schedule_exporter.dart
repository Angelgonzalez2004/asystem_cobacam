import 'package:flutter/foundation.dart'; // For compute function
import 'package:asystem_cobacam/utils/export_isolates.dart'; // Import the new isolate functions

// --- Existing imports ---


import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:gal/gal.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart'
    if (dart.library.html) 'package:asystem_cobacam/utils/web_downloader_web.dart';


// Assuming ClassSession is defined elsewhere and imported
import 'package:asystem_cobacam/models/class_session_model.dart';

/// Data class to encapsulate all information needed to display and export a schedule.
class ScheduleExportData {
  final String id; // Unique identifier for the schedule (e.g., group.key or teacher.id)
  final String name; // Name for the schedule (e.g., group.name or teacher.name)
  final String title;
  final String subtitle;
  final Map<String, List<ClassSession>> scheduleData;
  final String viewType;
  final String mainTitle;
  final String campusName;
  final String logoPath;

  ScheduleExportData({
    required this.id,
    required this.name,
    required this.title,
    required this.subtitle,
    required this.scheduleData,
    required this.viewType,
    required this.mainTitle,
    required this.campusName,
    required this.logoPath,
  });
}

class FileExporter {
  // Exports a single image to the gallery/downloads
  Future<bool> exportImage(Uint8List imageBytes, String fileName) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return false;
      }

      await Gal.putImageBytes(imageBytes, name: fileName);
      return true;
    } catch (e) {
      debugPrint('Error exporting image: $e');
      return false;
    }
  }

  // Exports a single image to a single-page PDF
  Future<bool> exportPdfSingle(Uint8List imageBytes, String fileName) async {
    try {
      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, // Set to landscape
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image),
            );
          },
        ),
      );

      final Uint8List pdfBytes = await compute(_savePdfInIsolate, pdf); // Use compute for pdf.save()
      await WebDownloader.downloadFile(pdfBytes, '$fileName.pdf', 'application/pdf');

      return true;
    } catch (e) {
      debugPrint('Error exporting single PDF: $e');
      return false;
    }
  }

  // Exports multiple images into a multi-page PDF, two per page
  Future<bool> exportPdfMulti(List<Uint8List> imagePages, String fileName) async {
    try {
      final Uint8List pdfBytes = await compute(generatePdfIsolate, imagePages); // Use compute
      await WebDownloader.downloadFile(pdfBytes, '$fileName.pdf', 'application/pdf');
      return true;
    } catch (e) {
      debugPrint('Error exporting multi-page PDF: $e');
      return false;
    }
  }

  // Exports multiple images into a ZIP archive
  Future<bool> exportImagesToZip(Map<String, Uint8List> images, String zipFileName) async {
    try {
      final Uint8List? zipBytes = await compute(generateZipIsolate, images); // Use compute
      if (zipBytes == null) return false;

      await WebDownloader.downloadFile(zipBytes, '$zipFileName.zip', 'application/zip');
      return true;
    } catch (e) {
      debugPrint('Error exporting images to ZIP: $e');
      return false;
    }
  }
}

// Top-level function for compute to save a single PDF
Future<Uint8List> _savePdfInIsolate(pw.Document pdf) async {
  return await pdf.save();
}