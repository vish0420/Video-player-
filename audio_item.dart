import 'package:photo_manager/photo_manager.dart';

/// A single playable audio file discovered through Android MediaStore.
class AudioItem {
  final AssetEntity asset;
  final String title;
  final String artist;
  final String album;
  final Duration duration;

  const AudioItem({
    required this.asset,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
  });

  Future<String?> resolvePath() async {
    final file = await asset.file;
    return file?.path;
  }
}
