import 'package:flutter/material.dart';

import '../../../shared/app_palette.dart';

/// 공지/건의 관리. 내용은 아직 비어 있다.
class AdminNoticeTab extends StatelessWidget {
  const AdminNoticeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '공지/건의 관리',
        style: TextStyle(
          fontSize: 16,
          color: AppPalette.of(context).textTertiary,
        ),
      ),
    );
  }
}
