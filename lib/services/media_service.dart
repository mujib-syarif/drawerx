import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

class MediaService {
  static Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();

    return result.isAuth;
  }

  static Future<AssetPathEntity?> getScreenshotAlbum() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);

    for (final album in albums) {
      final name = album.name.toLowerCase();

      if (name.contains('screenshot')) {
        return album;
      }
    }

    return null;
  }

  static Future<AssetEntity?> getLatestScreenshot() async {
    final album = await getScreenshotAlbum();

    if (album == null) {
      return null;
    }

    final totalCount = await album.assetCountAsync;

    if (totalCount == 0) {
      return null;
    }

    final assets = <AssetEntity>[];

    const pageSize = 100;

    for (int page = 0; page * pageSize < totalCount; page++) {
      final pageAssets = await album.getAssetListPaged(
        page: page,
        size: pageSize,
      );

      if (pageAssets.isEmpty) {
        break;
      }

      assets.addAll(pageAssets);
    }

    if (assets.isEmpty) {
      return null;
    }

    assets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    return assets.first;
  }

  static Future<Uint8List?> getThumbnail(AssetEntity asset) async {
    return asset.thumbnailDataWithSize(const ThumbnailSize(800, 800));
  }
}
