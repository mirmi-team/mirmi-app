import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api.dart';
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
        ? NetworkImage('$kBaseUrl/$_profileImage') as ImageProvider
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
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈'),
    _NavItem(icon: Icons.local_laundry_service_outlined, activeIcon: Icons.local_laundry_service, label: '세탁기'),
    _NavItem(icon: Icons.access_time_outlined, activeIcon: Icons.access_time_filled, label: '복귀/잔류'),
    _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: '공지/건의'),
    _NavItem(icon: Icons.music_note_outlined, activeIcon: Icons.music_note, label: '기상송'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: 8 + bottomPadding,
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                children: List.generate(_items.length, (i) {
                  final item = _items[i];
                  final selected = i == currentIndex;
                  return Expanded(
                    child: _NavBarItem(
                      item: item,
                      selected: selected,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavBarItem extends StatefulWidget {
  const _NavBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF00CFCD);
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    _controller.value = 1.0;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8FAFA).withValues(alpha: _controller.value),
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.selected ? widget.item.activeIcon : widget.item.icon,
              color: widget.selected ? _teal : const Color(0xFFBBBBBB),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              widget.item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                color: widget.selected ? _teal : const Color(0xFFBBBBBB),
              ),
            ),
          ],
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
