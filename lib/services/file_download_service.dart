// Mobile-specific file download implementation (Android/iOS)
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileDownloadService {
  static Future<String> downloadFile({
    required List<int> bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    Directory directory;

    if (Platform.isAndroid) {
      final publicDownloadDir = Directory('/storage/emulated/0/Download');
      if (await publicDownloadDir.exists()) {
        directory = publicDownloadDir;
      } else {
        final downloadsDir = await getDownloadsDirectory();
        final extDir = await getExternalStorageDirectory();
        final docsDir = await getApplicationDocumentsDirectory();
        directory = downloadsDir ?? extDir ?? docsDir;
      }
    } else {
      final downloadsDir = await getDownloadsDirectory();
      final docsDir = await getApplicationDocumentsDirectory();
      directory = downloadsDir ?? docsDir;
    }

    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    debugPrint('File saved to: $filePath');
    return filePath;
  }
}
