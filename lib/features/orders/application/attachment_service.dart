import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Copies a picture into the app's private folder, downscaled (max ~1280 px,
/// JPEG quality 75) so backups stay small (S2-13).
class AttachmentService {
  AttachmentService(this.baseDir, {this.maxEdge = 1280, this.quality = 75});

  final Directory baseDir;
  final int maxEdge;
  final int quality;

  /// Returns the stored file path.
  Future<String> store(File source, {required String orderId, required String fileId}) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    final dir = Directory(p.join(baseDir.path, 'attachments', orderId));
    await dir.create(recursive: true);
    final out = File(p.join(dir.path, '$fileId.jpg'));
    if (decoded == null) {
      // Unknown format: keep the original bytes rather than lose the proof.
      await out.writeAsBytes(bytes);
      return out.path;
    }
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longest <= maxEdge
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxEdge : null,
            height: decoded.height > decoded.width ? maxEdge : null,
          );
    await out.writeAsBytes(img.encodeJpg(resized, quality: quality));
    return out.path;
  }

  /// Removes every stored picture of an order (used by the purge job).
  Future<void> deleteForOrder(String orderId) async {
    final dir = Directory(p.join(baseDir.path, 'attachments', orderId));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
