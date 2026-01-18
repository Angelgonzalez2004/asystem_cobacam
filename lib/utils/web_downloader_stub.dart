import 'dart:typed_data';

class WebDownloader {
  static Future<void> downloadFile(Uint8List bytes, String fileName, String mimeType) async {
    throw UnsupportedError('File download not supported on this platform');
  }
}
