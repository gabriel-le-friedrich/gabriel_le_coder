// ══════════════════════════════════════════════════════════════════════
// Image compression — Dart/mobile equivalent of index.html's
// canvasToLimitedJpeg()/finalizePendingImage(): resize to a sane max edge,
// then step JPEG quality down (never below a floor) until the result fits
// under MAX_IMAGE_BYTES. There's no <canvas> on a native build, so this
// uses flutter_image_compress instead of redoing it by hand.
// ══════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const int kMaxImageBytes = 3 * 1024 * 1024;

class ImageCompressionService {
  /// Compresses [sourcePath] to at most [maxBytes], resizing to [maxEdge]
  /// on its longest side first, then stepping quality down from
  /// [startQuality] in steps of 10, never below [minQuality] — same
  /// progressive-quality-reduction idea as the web app's loop. Writes the
  /// result into the app's documents directory under [subfolder] and
  /// returns the new file's local path. Returns null (never throws) if
  /// compression genuinely can't hit the target — callers should show the
  /// same "Image exceeds 3 MB" message the web app does.
  static Future<String?> compressToPath({
    required String sourcePath,
    required String subfolder,
    required String fileName,
    int maxEdge = 640,
    int startQuality = 80,
    int minQuality = 35,
    int maxBytes = kMaxImageBytes,
  }) async {
    try {
      int quality = startQuality;
      Uint8List? bytes;
      while (quality >= minQuality) {
        bytes = await FlutterImageCompress.compressWithFile(
          sourcePath,
          minWidth: maxEdge,
          minHeight: maxEdge,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        if (bytes == null) return null;
        if (bytes.lengthInBytes <= maxBytes) break;
        quality -= 10;
      }
      if (bytes == null || bytes.lengthInBytes > maxBytes) return null;

      final dir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(dir.path, subfolder));
      if (!await targetDir.exists()) await targetDir.create(recursive: true);
      final targetPath = p.join(targetDir.path, fileName);
      await File(targetPath).writeAsBytes(bytes);
      return targetPath;
    } catch (_) {
      return null;
    }
  }
}
