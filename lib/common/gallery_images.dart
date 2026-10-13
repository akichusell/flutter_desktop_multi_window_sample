import 'package:flutter/services.dart';

const _folder = 'assets/images/';
const _extensions = ['.jpg', '.jpeg', '.png', '.webp'];

/// `assets/images/` 안의 이미지 경로 목록. 경로 자체를 이미지 id로 쓴다.
/// (실서비스라면 서버에서 받아 올 목록이라는 가정)
Future<List<String>> loadGalleryImages() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest
      .listAssets()
      .where((path) => path.startsWith(_folder))
      .where((path) => _extensions.any(path.toLowerCase().endsWith))
      .toList()
    ..sort();
}

/// `assets/images/cat.jpg` → `cat.jpg`
String fileNameOf(String imageId) => imageId.split('/').last;
