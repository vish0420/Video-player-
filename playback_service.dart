import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which video was played most recently, and how far into each
/// video the user got, so playback can resume where it left off.
class PlaybackService {
  static const _lastVideoKey = 'last_video_path';
  static const _positionPrefix = 'position_for_';

  Future<void> saveLastPlayed(String path, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastVideoKey, path);
    await prefs.setInt('$_positionPrefix$path', position.inMilliseconds);
  }

  Future<String?> getLastVideoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastVideoKey);
  }

  Future<Duration> getPosition(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_positionPrefix$path') ?? 0;
    return Duration(milliseconds: ms);
  }
}
