import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../laundry/laundry_screen.dart';
import '../return_stay/return_stay_screen.dart';
import '../notice/notice_screen.dart';
import '../song/song_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _profileImage;

  static const _bgColor = Color(0xFFF5F5F5);

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

  Future<void> _loadProfileImage() async {
    try {
      final user = await AuthService.getMe();
      if (mounted) setState(() => _profileImage = user['profile_image'] as String?);
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
      extendBody: true,
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
                backgroundColor: const Color(0xFFD9D9D9),
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 400) return;
          if (v < 0 && _currentIndex < _pages.length - 1) {
            setState(() => _currentIndex++);
          } else if (v > 0 && _currentIndex > 0) {
            setState(() => _currentIndex--);
          }
        },
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon});
  final IconData icon;
  final IconData activeIcon;
}

class _NavBar extends StatefulWidget {
  const _NavBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> with SingleTickerProviderStateMixin {
  static const _items = [
    _NavItem(icon: Icons.home_outlined,                  activeIcon: Icons.home_rounded),
    _NavItem(icon: Icons.local_laundry_service_outlined, activeIcon: Icons.local_laundry_service),
    _NavItem(icon: Icons.alarm_outlined,                 activeIcon: Icons.alarm),
    _NavItem(icon: Icons.notifications_outlined,         activeIcon: Icons.notifications),
    _NavItem(icon: Icons.music_note_outlined,            activeIcon: Icons.music_note),
  ];

  static const _spring = SpringDescription(mass: 1.0, stiffness: 280.0, damping: 24.0);

  late final AnimationController _ctrl;
  bool _pressed = false;
  late int _targetIndex;

  @override
  void initState() {
    super.initState();
    _targetIndex = widget.currentIndex;
    _ctrl = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() {}));
    _ctrl.value = widget.currentIndex.toDouble();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _targetIndex = widget.currentIndex;
      _springTo(widget.currentIndex.toDouble());
    }
  }

  void _springTo(double target, {double velocity = 0.0}) {
    _ctrl.animateWith(SpringSimulation(_spring, _ctrl.value, target, velocity));
  }

  void _select(int index, {double velocity = 0.0}) {
    setState(() => _targetIndex = index);
    widget.onTap(index);
    _springTo(index.toDouble(), velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final sysBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = Platform.isAndroid
        ? (sysBottom > 0 ? sysBottom + 8.0 : 24.0)
        : (sysBottom > 0 ? sysBottom - 8.0 : 16.0);

    return AnimatedScale(
      scale: _pressed ? 1.04 : 1.0,
      duration: Duration(milliseconds: _pressed ? 70 : 180),
      curve: Curves.easeOut,
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: bottomPad),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalW = constraints.maxWidth;
            final itemW  = totalW / _items.length;
            final pos    = _ctrl.value.clamp(0.0, (_items.length - 1).toDouble());

            const navH   = 66.0;
            const margin = 2.0;
            final slotL  = pos * itemW;
            final slotR  = slotL + itemW;

            return Listener(
              onPointerDown: (_) => setState(() => _pressed = true),
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _ctrl.stop(),
              onHorizontalDragUpdate: (d) {
                _ctrl.value = (_ctrl.value + d.delta.dx / itemW)
                    .clamp(0.0, (_items.length - 1).toDouble());
              },
              onHorizontalDragEnd: (d) {
                final v = (d.primaryVelocity ?? 0.0) / itemW;
                final int target;
                if (v > 2.0) {
                  target = pos.ceil().clamp(0, _items.length - 1);
                } else if (v < -2.0) {
                  target = pos.floor().clamp(0, _items.length - 1);
                } else {
                  target = pos.round().clamp(0, _items.length - 1);
                }
                _select(target, velocity: v);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      height: navH,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.40),
                          width: 1.0,
                        ),
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
                                color: const Color(0xFFE5E5E5),
                                borderRadius: BorderRadius.circular(navH / 2 - margin),
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(_items.length, (i) {
                              final active = _targetIndex == i;
                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _select(i),
                                  child: SizedBox(
                                    height: navH,
                                    child: Center(
                                      child: Icon(
                                        active ? _items[i].activeIcon : _items[i].icon,
                                        color: const Color(0xFF898989),
                                        size: 27.0,
                                        shadows: active
                                            ? const [
                                                Shadow(color: Color(0xFF898989), blurRadius: 1.8),
                                                Shadow(color: Color(0xFF898989), blurRadius: 1.8),
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
                  ),
                ),
              ),
            ),  // GestureDetector
            );  // Listener
          },
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
        style: TextStyle(fontSize: 18, color: Color(0xFF888888)),
      ),
    );
  }
}
