import 'package:flutter/material.dart';
import 'home_tab.dart';
import '../laundry/laundry_screen.dart';
import '../return_stay/return_stay_screen.dart';
import '../notice/notice_screen.dart';
import '../song/song_screen.dart';
import '../../shared/app_nav_bar.dart';
import '../../shared/app_top_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _navItems = [
  AppNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
  AppNavItem(
    icon: Icons.local_laundry_service_outlined,
    activeIcon: Icons.local_laundry_service,
  ),
  AppNavItem(icon: Icons.alarm_outlined, activeIcon: Icons.alarm),
  AppNavItem(
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
  ),
  AppNavItem(icon: Icons.music_note_outlined, activeIcon: Icons.music_note),
];

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();

  late final List<Widget> _pages = [
    const HomeTab(),
    LaundryScreen(),
    ReturnStayScreen(),
    NoticeScreen(),
    SongScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 하단바로 이동할 때는 화면이 밀리는 애니메이션 없이 즉시 전환한다.
  /// (손가락을 따라 움직이는 건 스와이프할 때만)
  void _goToPage(int index) => _pageController.jumpToPage(index);

  @override
  Widget build(BuildContext context) {
    // AppBar 뒤까지 그라데이션이 깔리도록 body 를 위로 확장하고,
    // 페이지들은 원래 위치(상태바 + AppBar 아래)에 오도록 그만큼 내려준다.
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      // 배경색은 지정하지 않는다. ThemeData.scaffoldBackgroundColor 가
      // 테마에 맞는 색을 넣어준다. 고정하면 라이트 모드에서 검은 배경이 남는다.
      extendBodyBehindAppBar: true,
      // 키보드가 올라와도 하단 네비게이션 바는 제자리에 둔다.
      // 대신 각 탭의 스크롤뷰가 키보드 높이만큼 하단 여백을 줘서
      // 입력창이 가려지지 않게 한다.
      resizeToAvoidBottomInset: false,
      appBar: const AppTopBar(),
      body: Stack(
        children: [
          _HomeGradient(pageController: _pageController),
          Padding(
            padding: EdgeInsets.only(top: topInset),
            // extendBodyBehindAppBar 를 켜면 상태바 패딩이 소비되지 않고 그대로
            // 내려가서, 각 페이지의 SafeArea(중첩 Scaffold, 배너)가 그만큼 또
            // 밀어낸다. 여기서 걷어내야 AppBar 아래 원래 위치에 붙는다.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: PageView(
                controller: _pageController,
                // 화면 전환은 하단 네비게이션 바로만. 좌우 스와이프는 막는다.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // PageView 는 화면 밖 페이지를 버리므로 그대로 두면 스와이프할 때마다
                  // 각 탭이 initState 부터 다시 돈다. (공지 탭이 매번 재요청)
                  for (final page in _pages) AppKeepAlivePage(child: page),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppNavBar(
              items: _navItems,
              controller: _pageController,
              onSelect: _goToPage,
            ),
          ),
        ],
      ),
    );
  }
}

/// 홈 상단 배경 그라데이션.
///
/// 세로로는 화면 맨 위에 고정되어 스크롤해도 움직이지 않는다.
/// 가로로는 페이지와 같은 속도로 밀려나가 화면 밖으로 사라지므로,
/// 세탁기·복귀 같은 다른 탭에는 보이지 않는다.
class _HomeGradient extends StatelessWidget {
  const _HomeGradient({required this.pageController});

  final PageController pageController;

  /// 상태바/AppBar 아래로 그라데이션이 이어지는 길이. 공지 줄 근처에서 사라진다.
  static const _contentExtent = 150.0;

  /// 테마별 상단 그라데이션.
  LinearGradient _gradientOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: isDark ? const [0.0, 1.0] : const [0.0, 0.5, 1.0],
      colors: isDark
          ? const [
              Color(0xFF003A49), // 0% - 불투명
              Color(0x00008DAF), // 100% - 투명
            ]
          : const [
              Color(0xFF86EDFF), // 0%
              Color(0xFFE3F8FC), // 50%
              Color(0xFFE9E9E9), // 100% - 기본 배경색과 같아 자연스럽게 이어진다
            ],
    );
  }

  double get _page {
    if (!pageController.hasClients) return 0;
    if (!pageController.position.haveDimensions) return 0;
    return pageController.page ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.padding.top + kToolbarHeight + _contentExtent;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: pageController,
          builder: (context, child) {
            final page = _page;
            if (page >= 1) return const SizedBox.shrink();

            // 페이지와 같이 옆으로만 밀려나간다. 세로는 고정.
            return Transform.translate(
              offset: Offset(-page * media.size.width, 0),
              child: child,
            );
          },
          child: Container(
            height: height,
            decoration: BoxDecoration(gradient: _gradientOf(context)),
          ),
        ),
      ),
    );
  }
}
