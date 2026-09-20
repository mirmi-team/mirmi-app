import 'package:flutter/material.dart';

import '../../shared/app_colors.dart';
import 'app_palette.dart';
import 'app_refresh.dart';

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.loadingButton = false,
    this.submitButton = false,
    this.errorButton = false,
  });
  final VoidCallback? onPressed;
  final String text;
  final bool loadingButton;
  final bool submitButton;
  final bool errorButton;

  static const _teal = AppBrand.primary;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: loadingButton ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: errorButton ? palette.statusError : _teal,
            // 비활성 버튼 색은 앱 전체가 borderDefault 로 통일.
            disabledBackgroundColor: palette.borderDefault,
            disabledForegroundColor: palette.textTertiary,
            // 라이트 모드에서는 어두운 글자가 되어야 읽힌다.
            foregroundColor: palette.textPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: loadingButton
              ? const AppLoadingIndicator.onButton()
              : Text(
                  text,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
