import 'package:flutter/material.dart';

import '../../../shared/app_palette.dart';

/// 세탁기 관리. 내용은 아직 비어 있다.
class AdminLaundryTab extends StatelessWidget {
  const AdminLaundryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '세탁기 관리',
        style: TextStyle(
          fontSize: 16,
          color: AppPalette.of(context).textTertiary,
        ),
      ),
    );
  }
}
