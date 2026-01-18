// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class WebDownloader {
  static Future<void> downloadFile(Uint8List bytes, String fileName, String mimeType) async {
    // Create a Blob from the bytes
    final blob = html.Blob([bytes], mimeType);

    // Create an object URL from the blob
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create a temporary anchor element
    // ignore: unused_local_variable
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName) // Set the download filename
      ..click(); // Programmatically click the anchor to trigger the download

    // Revoke the object URL to free up memory
    html.Url.revokeObjectUrl(url);
  }
}

