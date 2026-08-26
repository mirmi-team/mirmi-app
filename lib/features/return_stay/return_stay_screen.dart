import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';

class ReturnStayScreen extends StatelessWidget {
  const ReturnStayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '복귀/잔류',
        style: TextStyle(fontSize: 18, color: AppColors.placeholder),
      ),
    );
  }
}
