import 'package:flutter/material.dart';

import '../../shared/app_colors.dart';
import 'app_palette.dart';
import 'app_refresh.dart';

/// 화면 아래에 깔리는 공통 액션 버튼.
///
/// 전송·로그인·회원가입·예약이 모두 같은 모양이라 여기 하나로 모아 둔다.
/// [onPressed] 가 null 이거나 [loadingButton] 이면 비활성으로 그려진다.
///
/// ```dart
/// SubmitButton(text: '전송', onPressed: _canSubmit ? _submit : null)
/// ```
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.loadingButton = false,
    this.errorButton = false,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 28),
  });

  final VoidCallback? onPressed;
  final String text;

  /// 처리 중. 버튼을 잠그고 글자 대신 스피너를 보여준다.
  final bool loadingButton;

  /// 탈퇴처럼 되돌릴 수 없는 동작. 청록 대신 에러색으로 칠한다.
  final bool errorButton;

  /// 버튼 바깥 여백. 이미 여백이 있는 자리에 넣을 때 [EdgeInsets.zero] 를 준다.
  final EdgeInsetsGeometry padding;

  static const _teal = AppBrand.primary;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: loadingButton ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: errorButton ? palette.statusError : _teal,
            // 비활성 버튼 색은 앱 전체가 palette.disabledButton 으로 통일.
            disabledBackgroundColor: palette.disabledButton,
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
