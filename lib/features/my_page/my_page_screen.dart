import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_colors.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _uploading = false;
  File? _localImage;

  static const _teal        = AppColors.mainColor;
  static const _bgColor     = AppColors.backB;
  static const _textColor   = AppColors.mainText;
  static const _surfaceColor = AppColors.surfaceHover;
  static const _errorColor  = AppColors.error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthService.getMe();
      if (mounted) setState(() { _user = user; _loading = false; });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    String? filePath;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
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
      final rotated = await FlutterImageCompress.compressAndGetFile(filePath, tempPath, autoCorrectionAngle: true, quality: 85);
      if (rotated != null) uploadPath = rotated.path;

      if (mounted) setState(() => _localImage = File(uploadPath));

      final oldPath = _user?['profile_image'] as String?;
      if (oldPath != null) PaintingBinding.instance.imageCache.evict(NetworkImage(oldPath));

      final newPath = await AuthService.uploadProfileImage(uploadPath);
      if (mounted) {
        PaintingBinding.instance.imageCache.evict(NetworkImage(newPath));
        setState(() => _user = {...?_user, 'profile_image': newPath});
      }
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _localImage = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showImagePreview(ImageProvider imageProvider) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, a, b) => _ImagePreviewOverlay(imageProvider: imageProvider),
      transitionsBuilder: (_, animation, b, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  ImageProvider? _profileImageProvider() {
    if (_localImage != null) return FileImage(_localImage!);
    final path = _user?['profile_image'] as String?;
    if (path == null || path.isEmpty) return null;
    return NetworkImage(path);
  }

  void _logout() => context.push('/logout');

  void _deleteAccount() => context.push('/delete-account');

  @override
  Widget build(BuildContext context) {
    final name       = _user?['username']    as String? ?? '';
    final grade      = _user?['grade']       as int?;
    final classNo    = _user?['class_no']    as int?;
    final roomNumber = _user?['room_number'] as int?;
    final demerits   = _user?['total_merit_score'] as int?;
    final imageProvider = _profileImageProvider();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _surfaceColor, shape: BoxShape.circle),
              child: const Icon(Icons.chevron_left, color: _textColor, size: 22),
            ),
          ),
        ),
        title: Text(
          _loading ? '' : '$name님의 정보',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _textColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // ── 프로필 사진 ────────────────────────────────
                  Stack(
                    children: [
                      GestureDetector(
                        onLongPress: imageProvider != null ? () => _showImagePreview(imageProvider) : null,
                        child: Hero(
                          tag: 'profile_photo',
                          child: Container(
                            width: 100, height: 100,
                            decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle),
                            clipBehavior: Clip.antiAlias,
                            child: imageProvider == null
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : Image(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.person, size: 50, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: GestureDetector(
                          onTap: _uploading ? null : _pickAndUploadImage,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: _teal, shape: BoxShape.circle, border: Border.all(color: _bgColor, width: 2)),
                            child: _uploading
                                ? const Padding(padding: EdgeInsets.all(5), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.edit, color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── 이름 ──────────────────────────────────────
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),

                  const SizedBox(height: 28),

                  // ── 호실·학년반·상벌점 ────────────────────────
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _InfoCell(
                          value: roomNumber != null ? '$roomNumber호' : '-',
                          label: '호실',
                        ),
                        _InfoCell(
                          value: (grade != null && classNo != null) ? '$grade학년 $classNo반' : '-',
                          label: '학년•반',
                        ),
                        _InfoCell(
                          value: demerits != null ? '$demerits점' : '-',
                          label: '상벌점',
                          valueColor: demerits != null && demerits < 0 ? _errorColor : _textColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── 메뉴 리스트 ───────────────────────────────
                  _MenuItem(label: '상벌점 내역',  onTap: () => context.push('/merit-logs')),
                  const SizedBox(height: 20),
                  _MenuItem(label: '비밀번호 변경', onTap: () => context.push('/change-password')),
                  const SizedBox(height: 20),
                  _MenuItem(label: '로그아웃',    onTap: _logout),
                  const SizedBox(height: 20),
                  _MenuItem(label: '회원 탈퇴',   onTap: _deleteAccount, labelColor: _errorColor),
                ],
              ),
            ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.value, required this.label, this.valueColor});
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.mainText)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.caption)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, required this.onTap, this.labelColor});
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, color: labelColor ?? AppColors.mainText)),
            Icon(Icons.chevron_right, color: Colors.white, size: 26),
          ],
        ),
      ),
    );
  }
}

// ── 이미지 프리뷰 오버레이 ─────────────────────────────────────────────

class _ImagePreviewOverlay extends StatefulWidget {
  const _ImagePreviewOverlay({required this.imageProvider});
  final ImageProvider imageProvider;

  @override
  State<_ImagePreviewOverlay> createState() => _ImagePreviewOverlayState();
}

class _ImagePreviewOverlayState extends State<_ImagePreviewOverlay> {
  double _scale = 1.0;
  double _startScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onScaleStart:  (_) => _startScale = _scale,
            onScaleUpdate: (d) => setState(() => _scale = (_startScale * d.scale).clamp(1.0, 4.0)),
            onScaleEnd:    (_) => setState(() => _scale = 1.0),
            child: Transform.scale(
              scale: _scale,
              child: Hero(
                tag: 'profile_photo',
                child: ClipOval(
                  child: Image(image: widget.imageProvider, width: 280, height: 280, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
