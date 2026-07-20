import 'package:photo_manager/photo_manager.dart';

import '../models/video_item.dart';

/// Finds videos on the device using the system MediaStore, which covers
/// both internal phone storage and a removable SD card automatically -
/// the same mechanism most video player apps rely on.
class VideoScannerService {
  /// Requests storage/media permission. Returns true if the app has at
  /// least limited access to videos.
  Future<bool> requestPermission() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  /// Scans and returns every video the OS knows about, newest first.
  Future<List<VideoItem>> scanVideos() async {
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];

    final AssetPathEntity all = paths.first;
    final int count = await all.assetCountAsync;
    final List<AssetEntity> assets = await all.getAssetListPaged(
      page: 0,
      size: count,
    );

    assets.sort((a, b) => b.modifiedDateTime.compareTo(a.modifiedDateTime));

    return assets
        .map(
          (a) => VideoItem(
            asset: a,
            title: a.title?.isNotEmpty == true ? a.title! : 'Untitled video',
            duration: Duration(seconds: a.duration),
          ),
        )
        .toList();
  }
}
