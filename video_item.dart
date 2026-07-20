import 'package:photo_manager/photo_manager.dart';

/// A single playable video found on the device (internal storage or SD card).
///
/// Wraps a [AssetEntity] from `photo_manager`, which is how we get access to
/// videos indexed by Android's MediaStore without needing raw filesystem
/// permissions on newer Android versions.
class VideoItem {
  final AssetEntity asset;
  final String title;
  final Duration duration;

  const VideoItem({
    required this.asset,
    required this.title,
    required this.duration,
  });

  /// Resolves the actual file path on disk, needed by the player and by
  /// the share sheet. Returns null if the file can no longer be found
  /// (e.g. it was deleted after the library was scanned).
  Future<String?> resolvePath() async {
    final file = await asset.file;
    return file?.path;
  }
}
