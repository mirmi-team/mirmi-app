import 'package:flutter/material.dart';

import 'app_palette.dart';

/// 입력 항목 위에 붙는 안내 라벨. ('1. 카테고리를 선택해 주세요.')
///
/// 건의 폼과 잔류/외박 신청이 같은 모양을 쓴다.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: AppPalette.of(context).textSecondary,
      ),
    );
  }
}
