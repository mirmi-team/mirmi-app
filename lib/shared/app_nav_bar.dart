import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'app_colors.dart';

/// PageView 안에서 화면 밖으로 나가도 상태를 유지시킨다.
class AppKeepAlivePage extends StatefulWidget {
  const AppKeepAlivePage({super.key, required this.child});
  final Widget child;

  @override
  State<AppKeepAlivePage> createState() => _AppKeepAlivePageState();
}

class _AppKeepAlivePageState extends State<AppKeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// 하단 네비게이션 바의 칸 하나.
class AppNavItem {
  const AppNavItem({required this.icon, required this.activeIcon});
  final IconData icon;
  final IconData activeIcon;
}

class AppNavBar extends StatefulWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.controller,
    required this.onSelect,
  });

  /// 왼쪽부터 순서대로. 페이지 순서와 같아야 한다.
  final List<AppNavItem> items;

  /// 페이지와 알약(선택 표시)이 같은 값을 보도록 컨트롤러를 공유한다.
  final PageController controller;
  final ValueChanged<int> onSelect;

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar>
    with SingleTickerProviderStateMixin {
  int get _maxIndex => widget.items.length - 1;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 280.0,
    damping: 24.0,
  );

  /// 알약 위치.
  ///
  /// 스와이프 중에는 페이지를 그대로 따라가 손가락에 붙어 움직이고,
  /// 하단바로 이동할 때는 페이지가 즉시 바뀌므로 알약만 여기서 스프링으로 움직인다.
  late final AnimationController _pill;

  /// 하단바가 일으킨 페이지 점프인지. 이때는 알약이 페이지를 따라 튀지 않게 한다.
  bool _jumping = false;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pill = AnimationController.unbounded(vsync: this);
    _pill.value = widget.controller.initialPage.toDouble();
    widget.controller.addListener(_followPage);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_followPage);
    _pill.dispose();
    super.dispose();
  }

  /// 현재 페이지 위치(소수). 스와이프 중에는 손가락을 따라 연속으로 변한다.
  double get _pagePosition {
    final controller = widget.controller;
    if (controller.hasClients && controller.position.haveDimensions) {
      return (controller.page ?? 0).clamp(0.0, _maxIndex.toDouble());
    }
    return controller.initialPage.toDouble();
  }

  /// 페이지가 움직이면 알약도 같은 위치로 붙인다.
  void _followPage() {
    if (_jumping) return;
    _pill.stop();
    _pill.value = _pagePosition;
  }

  /// 하단바에서 선택. 페이지는 즉시 옮기고 알약만 스프링으로 따라간다.
  void _select(int index) {
    _jumping = true;
    widget.onSelect(index); // jumpToPage — 리스너가 동기로 불린다
    _jumping = false;
    _pill.animateWith(
      SpringSimulation(_spring, _pill.value, index.toDouble(), 0.0),
    );
  }

  /// 네비게이션 바를 끄는 동안에는 알약만 움직인다. 화면은 그대로 두고,
  /// 손을 놓은 칸으로 그때 한 번에 이동한다.
  void _dragPill(double dx, double itemWidth) {
    _pill.stop();
    _pill.value = (_pill.value + dx / itemWidth).clamp(
      0.0,
      _maxIndex.toDouble(),
    );
  }

  /// 놓은 자리가 현재 페이지면 알약만 제자리로 돌리고 화면은 건드리지 않는다.
  void _endPillDrag(int target) {
    final current = _pagePosition.round();
    if (target == current) {
      _pill.animateWith(
        SpringSimulation(_spring, _pill.value, current.toDouble(), 0.0),
      );
      return;
    }
    _select(target);
  }

  /// 네비게이션 바 색. 다크는 반투명 유리, 라이트는 흰 바에 옅은 그림자.
  ({Color bar, Color barBorder, Color shadow, Color pill, Color icon})
  _navColorsOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 채움과 테두리는 두 모드가 같은 투명도를 쓴다. (반투명 유리 느낌)
    // 알약·아이콘·그림자만 배경 밝기에 맞춰 달라진다.
    const bar = Color(0x14FFFFFF); // 흰색 8%
    const whiteBar = Color(0xA6F7F7F7); // 흰색 97%
    final barBorder = AppColors.hint.withValues(alpha: 0.40);

    if (isDark) {
      return (
        bar: bar,
        barBorder: barBorder,
        shadow: Colors.black,
        pill: AppDark.bgSurfaceHover,
        icon: AppColors.navIcon,
      );
    }
    return (
      bar: whiteBar,
      barBorder: barBorder,
      // 검은 그림자를 그대로 쓰면 밝은 배경에서 너무 진하다.
      shadow: AppLight.textPrimary.withValues(alpha: 0.21),
      // 다크의 알약(27272A)과 같이 불투명. 다크는 배경보다 한 단계 밝고,
      // 라이트는 같은 논리로 한 단계 어두운 회색을 쓴다.
      pill: Color(0xFFD1D1D1),
      icon: AppLight.textTertiary,
    );
  }

  @override
  Widget build(BuildContext context) {
    // padding 이 아니라 viewPadding 을 쓴다. padding.bottom 은 키보드가 올라오는
    // 동안 0 으로 줄어드는데, iOS 분기의 (sysBottom - 8) 이 음수가 되어
    // Padding 이 assertion 으로 터진다. viewPadding 은 키보드와 무관하게 고정이라
    // 네비바 높이도 흔들리지 않는다.
    final nav = _navColorsOf(context);
    final sysBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPad = Platform.isAndroid
        ? (sysBottom > 0 ? sysBottom + 8.0 : 24.0)
        : (sysBottom > 0 ? math.max(sysBottom - 8.0, 0.0) : 16.0);

    return AnimatedBuilder(
      // 알약이 움직일 때마다 다시 그린다. (스와이프 중에는 페이지를 따라가고,
      // 하단바로 이동할 때는 스프링으로 움직인다.)
      animation: _pill,
      builder: (context, _) => AnimatedScale(
        scale: _pressed ? 1.04 : 1.0,
        duration: Duration(milliseconds: _pressed ? 70 : 180),
        curve: Curves.easeOut,
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: bottomPad),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final itemW = totalW / widget.items.length;
              final pos = _pill.value.clamp(0.0, _maxIndex.toDouble());

              const navH = 66.0;
              const margin = 2.0;
              final slotL = pos * itemW;
              final slotR = slotL + itemW;

              return Listener(
                onPointerDown: (_) => setState(() => _pressed = true),
                onPointerUp: (_) => setState(() => _pressed = false),
                onPointerCancel: (_) => setState(() => _pressed = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _pill.stop(),
                  onHorizontalDragUpdate: (d) => _dragPill(d.delta.dx, itemW),
                  onHorizontalDragEnd: (d) {
                    final v = (d.primaryVelocity ?? 0.0) / itemW;
                    final int target;
                    if (v > 2.0) {
                      target = pos.ceil().clamp(0, _maxIndex);
                    } else if (v < -2.0) {
                      target = pos.floor().clamp(0, _maxIndex);
                    } else {
                      target = pos.round().clamp(0, _maxIndex);
                    }
                    _endPillDrag(target);
                  },
                  child: Container(
                    height: navH,
                    decoration: BoxDecoration(
                      color: nav.bar,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: nav.barBorder, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: nav.shadow,
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: slotL + margin,
                          right: totalW - slotR + margin,
                          top: margin,
                          bottom: margin,
                          child: Container(
                            decoration: BoxDecoration(
                              color: nav.pill,
                              borderRadius: BorderRadius.circular(
                                navH / 2 - margin,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(widget.items.length, (i) {
                            final active = pos.round() == i;
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _select(i),
                                child: SizedBox(
                                  height: navH,
                                  child: Center(
                                    child: Icon(
                                      active
                                          ? widget.items[i].activeIcon
                                          : widget.items[i].icon,
                                      color: active
                                          ? AppBrand.primary
                                          : nav.icon,
                                      size: 27.0,
                                      shadows: active
                                          ? const [
                                              Shadow(
                                                color: AppBrand.primary,
                                                blurRadius: 1.8,
                                              ),
                                              Shadow(
                                                color: AppBrand.primary,
                                                blurRadius: 1.8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ), // GestureDetector
              ); // Listener
            },
          ),
        ),
      ),
    );
  }
}
