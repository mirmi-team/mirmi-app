import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Stack 안에서 상단 슬라이드 배너를 띄우는 mixin.
/// State 클래스에 `with AppBannerMixin` 추가 후
/// body를 Stack으로 감싸고 마지막 자식으로 `buildBanner()` 추가.
mixin AppBannerMixin<T extends StatefulWidget> on State<T> {
  bool _bannerVisible = false;
  String? _bannerMessage;
  Color _bannerColor = AppColors.error;
  IconData _bannerIcon = Icons.priority_high_rounded;

  void showErrorBanner(String msg) => _show(msg, AppColors.error, Icons.priority_high_rounded);
  void showSuccessBanner(String msg) => _show(msg, AppColors.mainColor, Icons.check);
  void showInfoBanner(String msg) => _show(msg, AppColors.mainColor, Icons.info_outline);

  void _show(String msg, Color color, IconData icon) {
    setState(() {
      _bannerMessage = msg;
      _bannerColor   = color;
      _bannerIcon    = icon;
      _bannerVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _bannerVisible = true);
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _bannerVisible = false);
      });
    });
  }

  /// Stack의 자식으로 추가. _bannerMessage가 null이면 빈 위젯 반환.
  Widget buildBanner() {
    if (_bannerMessage == null) return const SizedBox.shrink();
    final color = _bannerColor;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRect(
        child: SafeArea(
          child: AnimatedSlide(
            offset: _bannerVisible ? Offset.zero : const Offset(0, -3),
            duration: const Duration(milliseconds: 400),
            curve: _bannerVisible ? Curves.easeOut : Curves.easeIn,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: Icon(_bannerIcon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _bannerMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
