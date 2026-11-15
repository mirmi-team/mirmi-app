import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 갤러리에서 사진 한 장을 고른다. 고르지 않고 닫으면 null.
///
/// 안드로이드는 [FilePicker] 를 쓴다. 기기에 따라 [ImagePicker] 가 경로를
/// 돌려주지 않는 일이 있어서다.
///
/// 압축을 따로 떼어 둔 이유: 호출하는 쪽이 사진을 고른 직후에 로딩 표시를
/// 켜고, 그 다음에 [compressImage] 를 돌릴 수 있도록.
Future<String?> pickImageFile() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final file = result?.files.firstOrNull;
    return file?.path ?? file?.xFile.path;
  }
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  return picked?.path;
}

/// 회전 보정과 압축을 거친 파일 경로.
///
/// 압축에 실패하면 원본 경로를 그대로 돌려준다. (올리기는 해야 한다)
Future<String> compressImage(String filePath) async {
  final tmpDir = await getTemporaryDirectory();
  final tempPath =
      '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
  final rotated = await FlutterImageCompress.compressAndGetFile(
    filePath,
    tempPath,
    autoCorrectionAngle: true,
    quality: 85,
  );
  return rotated?.path ?? filePath;
}
