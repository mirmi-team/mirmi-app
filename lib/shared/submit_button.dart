import 'package:flutter/material.dart';

import '../../shared/app_colors.dart';
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

  static const _teal = AppColors.mainColor;
  static const _surfaceColor = AppColors.surfaceHover;
  static const _captionColor = AppColors.caption;
  static const _errorColor = AppColors.error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: loadingButton ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: errorButton ? _errorColor : _teal,
            disabledBackgroundColor: _surfaceColor,
            disabledForegroundColor: _captionColor,
            foregroundColor: Colors.white,
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
