import 'package:flutter/material.dart';

import '../../../shared/app_palette.dart';

/// 복귀/잔류 관리. 내용은 아직 비어 있다.
class AdminReturnTab extends StatelessWidget {
  const AdminReturnTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '복귀/잔류 관리',
        style: TextStyle(
          fontSize: 16,
          color: AppPalette.of(context).textTertiary,
        ),
      ),
    );
  }
}
