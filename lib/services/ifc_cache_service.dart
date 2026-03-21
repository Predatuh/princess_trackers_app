import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class IfcCacheService {
  static Future<Directory> _cacheDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/ifc_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _safeName(String? filename, int blockId) {
    final raw = (filename == null || filename.trim().isEmpty)
        ? 'block_$blockId.pdf'
        : filename.trim();
    final normalized = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return normalized.toLowerCase().endsWith('.pdf') ? normalized : '$normalized.pdf';
  }

  static Future<File> fileForBlock(int blockId, {String? filename}) async {
    final dir = await _cacheDir();
    final safeName = _safeName(filename, blockId);
    return File('${dir.path}/${blockId}_$safeName');
  }

  static Future<File?> existingFileForBlock(int blockId, {String? filename}) async {
    final file = await fileForBlock(blockId, filename: filename);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  static Future<File> storePdfBytes(
    int blockId,
    Uint8List bytes, {
    String? filename,
  }) async {
    final target = await fileForBlock(blockId, filename: filename);
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    return temp.rename(target.path);
  }
}