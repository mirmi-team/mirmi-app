import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 자식(보통 스크롤뷰)의 높이를 키보드 위까지로 줄인다.
///
/// 홈 Scaffold 는 `resizeToAvoidBottomInset: false` 라서 화면이 키보드만큼
/// 줄지 않는다. 그래서 스크롤뷰가 여전히 키보드 뒤까지 뻗어 있다고 생각하고,
/// 포커스된 입력창을 위로 끌어올려 주지 않는다.
///
/// 스크롤뷰 **안쪽 padding** 으로 여백을 주는 것과는 다르다. 그건 스크롤 가능한
/// 길이만 늘릴 뿐 뷰포트는 그대로라 자동 스크롤이 일어나지 않는다.
/// 여기서는 뷰포트 자체를 줄이므로, 입력창에 포커스가 가면 Flutter 가 알아서
/// 키보드 위로 스크롤해 준다.
class KeyboardInset extends StatelessWidget {
  const KeyboardInset({super.key, required this.child, this.below = 0});

  final Widget child;

  /// 이 위젯 **아래에** 이미 자리를 차지하고 있는 높이.
  /// (하단 고정 버튼, 네비게이션 바 자리 등)
  ///
  /// 키보드는 화면 맨 아래에서 올라오므로, 그 높이만큼은 이미 키보드에 가려진다.
  /// 이를 빼지 않고 키보드 높이 전체를 줄이면 이중으로 비어서 스크롤 끝과
  /// 키보드 사이에 빈 박스가 생긴다.
  final double below;

  /// 키보드가 올라와 있으면 true.
  static bool isOpen(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0;

  /// 스크롤뷰 하단에 남겨둘 여백.
  ///
  /// 평소에는 하단 네비게이션 바 자리를 비우지만, 키보드가 올라오면 네비바가
  /// 키보드 뒤에 가려지므로 그만큼을 비워둘 필요가 없다.
  ///
  /// 키보드 높이에 따라 연속적으로 줄인다. "키보드가 떠 있으면 24" 같은
  /// 계단식으로 만들면 애니메이션 도중 값이 한 번에 튀어서 여백이
  /// 사라졌다 생겼다 하는 것처럼 보인다.
  static double bottomReserve(BuildContext context, {double navBar = 110}) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return math.max(navBar - keyboard, 24);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: math.max(keyboard - below, 0)),
      child: child,
    );
  }
}
