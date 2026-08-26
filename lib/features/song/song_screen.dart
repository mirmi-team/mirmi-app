import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';

class SongScreen extends StatelessWidget {
  const SongScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '기상송',
        style: TextStyle(fontSize: 18, color: AppColors.placeholder),
      ),
    );
  }
}
