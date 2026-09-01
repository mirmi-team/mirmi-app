import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../laundry/laundry_screen.dart';
import '../return_stay/return_stay_screen.dart';
import '../notice/notice_screen.dart';
import '../song/song_screen.dart';
import '../../shared/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _bgColor = AppColors.backB;

  final PageController _pageController = PageController();
  String? _profileImage;

  final List<Widget> _pages = const [
    _HomeTab(),
    LaundryScreen(),
    ReturnStayScreen(),
    NoticeScreen(),
    SongScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 하단바로 이동할 때는 화면이 밀리는 애니메이션 없이 즉시 전환한다.
  /// (손가락을 따라 움직이는 건 스와이프할 때만)
  void _goToPage(int index) => _pageController.jumpToPage(index);

  Future<void> _loadProfileImage() async {
    try {
      final user = await AuthService.getMe();
      if (mounted)
        setState(() => _profileImage = user['profile_image'] as String?);
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {}
  }

  Future<void> _goToMyPage() async {
    await context.push('/my');
    _loadProfileImage();
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = (_profileImage != null && _profileImage!.isNotEmpty)
        ? NetworkImage(_profileImage!) as ImageProvider
        : null;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Image.asset('assets/img/MIRMI.png', height: 18),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: _goToMyPage,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.avatarBg,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // PageView 는 손가락을 따라 페이지가 같이 밀리고, 놓으면 이어서 넘어간다.
          PageView(
            controller: _pageController,
            children: [
              // PageView 는 화면 밖 페이지를 버리므로 그대로 두면 스와이프할 때마다
              // 각 탭이 initState 부터 다시 돈다. (공지 탭이 매번 재요청)
              for (final page in _pages) _KeepAlivePage(child: page),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _NavBar(controller: _pageController, onSelect: _goToPage),
          ),
        ],
      ),
    );
  }
}

/// PageView 안에서 화면 밖으로 나가도 상태를 유지시킨다.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon});
  final IconData icon;
  final IconData activeIcon;
}

class _NavBar extends StatefulWidget {
  const _NavBar({required this.controller, required this.onSelect});

  /// 페이지와 알약(선택 표시)이 같은 값을 보도록 컨트롤러를 공유한다.
  final PageController controller;
  final ValueChanged<int> onSelect;

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar>
    with SingleTickerProviderStateMixin {
  static const _surfaceColor = AppColors.surfaceHover;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    _NavItem(
      icon: Icons.local_laundry_service_outlined,
      activeIcon: Icons.local_laundry_service,
    ),
    _NavItem(icon: Icons.alarm_outlined, activeIcon: Icons.alarm),
    _NavItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
    ),
    _NavItem(icon: Icons.music_note_outlined, activeIcon: Icons.music_note),
  ];

  static final _maxIndex = _items.length - 1;

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

  /// 네비게이션 바를 직접 끌 때도 페이지가 같이 따라오게 한다.
  /// 바에서 한 칸 이동 = 페이지 한 장.
  void _dragBy(double dx, double itemWidth) {
    final position = widget.controller.position;
    if (!position.haveDimensions) return;
    final pixels =
        position.pixels + dx / itemWidth * position.viewportDimension;
    widget.controller.jumpTo(
      pixels.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sysBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = Platform.isAndroid
        ? (sysBottom > 0 ? sysBottom + 8.0 : 24.0)
        : (sysBottom > 0 ? sysBottom - 8.0 : 16.0);

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
              final itemW = totalW / _items.length;
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
                  onHorizontalDragUpdate: (d) => _dragBy(d.delta.dx, itemW),
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
                    _select(target);
                  },
                  child: Container(
                    height: navH,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: AppColors.hint.withValues(alpha: 0.40),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 1),
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
                              color: _surfaceColor,
                              borderRadius: BorderRadius.circular(
                                navH / 2 - margin,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(_items.length, (i) {
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
                                          ? _items[i].activeIcon
                                          : _items[i].icon,
                                      color: AppColors.navIcon,
                                      size: 27.0,
                                      shadows: active
                                          ? const [
                                              Shadow(
                                                color: AppColors.navIcon,
                                                blurRadius: 1.8,
                                              ),
                                              Shadow(
                                                color: AppColors.navIcon,
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

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '홈',
        style: TextStyle(fontSize: 18, color: AppColors.placeholder),
      ),
    );
  }
}
