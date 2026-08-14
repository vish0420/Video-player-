import 'package:photo_manager/photo_manager.dart';

import '../models/audio_item.dart';

class AudioScannerService {
  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  Future<List<AudioItem>> scanAudio() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.audio,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];

    final all = paths.first;
    final count = await all.assetCountAsync;
    if (count == 0) return [];

    final assets = await all.getAssetListPaged(page: 0, size: count);
    assets.sort((a, b) => b.modifiedDateTime.compareTo(a.modifiedDateTime));

    return assets.map((a) {
      final title = a.title?.trim();
      return AudioItem(
        asset: a,
        title: title?.isNotEmpty == true ? title! : 'Untitled audio',
        artist: 'Unknown artist',
        album: 'Unknown album',
        duration: Duration(seconds: a.duration),
      );
    }).toList();
  }
}
