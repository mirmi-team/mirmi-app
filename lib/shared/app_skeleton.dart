import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 로딩 중 자리를 대신 잡아주는 블록.
///
/// 화면 전체를 스피너로 덮는 대신, 정적인 요소는 그대로 보여주고 데이터가
/// 필요한 자리에만 놓는다. 은은하게 밝기가 오가서 로딩 중임이 드러난다.
///
/// ```dart
/// _loading ? const AppSkeleton(width: 140, height: 20) : Text(username)
/// ```
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width, this.height = 16, this.radius = 8});

  /// null이면 가로를 꽉 채운다.
  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.card, AppColors.surfaceHover, t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// 스켈레톤에서 실제 내용으로 부드럽게 바뀌도록 감싸는 헬퍼.
class AppSkeletonSwitcher extends StatelessWidget {
  const AppSkeletonSwitcher({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      // 기본 layoutBuilder 는 Stack(alignment: center) 라 글자가 가운데로 몰린다.
      // 일반 Column 흐름처럼 좌상단에 붙도록 바꾼다.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previousChildren, ?currentChild],
      ),
      child: loading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
