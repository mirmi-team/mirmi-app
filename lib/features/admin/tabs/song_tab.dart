import 'package:flutter/material.dart';

import '../../../shared/app_palette.dart';

/// 기상송 관리. 내용은 아직 비어 있다.
class AdminSongTab extends StatelessWidget {
  const AdminSongTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '기상송 관리',
        style: TextStyle(
          fontSize: 16,
          color: AppPalette.of(context).textTertiary,
        ),
      ),
    );
  }
}
