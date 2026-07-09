import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/api.dart';
import '../../core/services/auth_service.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _uploading = false;
  File? _localImage; // 선택 직후 즉시 표시할 로컬 파일

  static const _teal = Color(0xFF00CFCD);
  static const _bgColor = Color(0xFFF2F3F5);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthService.getMe();
      if (mounted) setState(() { _user = user; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    String? filePath;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      final file = result?.files.firstOrNull;
      filePath = file?.path ?? file?.xFile.path;
    } else {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      filePath = picked?.path;
    }

    if (!mounted || filePath == null) return;

    setState(() => _uploading = true);
    try {
      final tmpDir = await getTemporaryDirectory();
      final tempPath = '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      String uploadPath = filePath;
      final rotated = await FlutterImageCompress.compressAndGetFile(
        filePath,
        tempPath,
        autoCorrectionAngle: true,
        quality: 85,
      );
      if (rotated != null) uploadPath = rotated.path;

      // 압축 완료 즉시 로컬 파일로 UI 반영
      if (mounted) setState(() => _localImage = File(uploadPath));

      final oldPath = _user?['profile_image'] as String?;
      if (oldPath != null) {
        PaintingBinding.instance.imageCache.evict(NetworkImage('$kBaseUrl/$oldPath'));
      }

      final newPath = await AuthService.uploadProfileImage(uploadPath);
      if (mounted) {
        PaintingBinding.instance.imageCache.evict(NetworkImage('$kBaseUrl/$newPath'));
        setState(() => _user = {...?_user, 'profile_image': newPath});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localImage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  void _showImagePreview(ImageProvider imageProvider) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, a, b) => _ImagePreviewOverlay(imageProvider: imageProvider),
        transitionsBuilder: (_, animation, b, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  ImageProvider? _profileImageProvider() {
    if (_localImage != null) return FileImage(_localImage!);
    final path = _user?['profile_image'] as String?;
    if (path == null || path.isEmpty) return null;
    return NetworkImage('$kBaseUrl/$path');
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['username'] as String? ?? '';
    final grade = _user?['grade'] as int?;
    final classNo = _user?['class_no'] as int?;
    final roomId = _user?['room_id'] as int?;
    final imageProvider = _profileImageProvider();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _loading ? '' : '$name님의 정보',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  Stack(
                    children: [
                      GestureDetector(
                        onLongPress: imageProvider != null
                            ? () => _showImagePreview(imageProvider)
                            : null,
                        child: Hero(
                          tag: 'profile_photo',
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD9D9D9),
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imageProvider == null
                                ? const Icon(Icons.person, size: 52, color: Colors.white)
                                : Image(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, e, s) => const Icon(
                                      Icons.person,
                                      size: 52,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _uploading ? null : _pickAndUploadImage,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _teal,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _uploading
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.edit, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (grade != null && classNo != null && roomId != null)
                        ? '$grade학년 $classNo반 • $roomId호'
                        : '',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEEEEEE),
                        foregroundColor: Colors.black54,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ImagePreviewOverlay extends StatefulWidget {
  const _ImagePreviewOverlay({required this.imageProvider});
  final ImageProvider imageProvider;

  @override
  State<_ImagePreviewOverlay> createState() => _ImagePreviewOverlayState();
}


class _ImagePreviewOverlayState extends State<_ImagePreviewOverlay> {
  double _scale = 1.0;
  double _startScale = 1.0;

  void _onScaleStart(ScaleStartDetails _) {
    _startScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() => _scale = (_startScale * details.scale).clamp(1.0, 4.0));
  }

  void _onScaleEnd(ScaleEndDetails _) {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: Transform.scale(
              scale: _scale,
              child: Hero(
                tag: 'profile_photo',
                child: ClipOval(
                  child: Image(
                    image: widget.imageProvider,
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
