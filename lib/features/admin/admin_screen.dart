import 'package:flutter/material.dart';

import '../../shared/app_nav_bar.dart';
import '../../shared/app_top_bar.dart';
import 'admin_player.dart';
import 'tabs/laundry_tab.dart';
import 'tabs/notice_tab.dart';
import 'tabs/return_tab.dart';
import 'tabs/song_tab.dart';
import 'tabs/student_tab.dart';

/// 사감(ADMIN) 전용 화면. 학생 화면 대신 이쪽으로 들어온다.
///
/// 껍데기는 학생 홈과 같다. 상단바와 하단 네비게이션 바를 그대로 쓰고
/// 탭 구성만 다르다.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

/// 탭 순서. 아래 _pages 와 같은 순서여야 한다.
const _navItems = [
  // 학생 정보 관리
  AppNavItem(icon: Icons.people_outline, activeIcon: Icons.people),
  // 세탁기 관리
  AppNavItem(
    icon: Icons.local_laundry_service_outlined,
    activeIcon: Icons.local_laundry_service,
  ),
  // 복귀/잔류 관리
  AppNavItem(icon: Icons.how_to_reg_outlined, activeIcon: Icons.how_to_reg),
  // 공지/건의 관리
  AppNavItem(icon: Icons.campaign_outlined, activeIcon: Icons.campaign),
  // 기상송 관리
  AppNavItem(icon: Icons.music_note_outlined, activeIcon: Icons.music_note),
];

class _AdminScreenState extends State<AdminScreen> {
  final PageController _pageController = PageController();

  /// 기상송 이어 재생. 탭을 옮겨도 소리가 끊기지 않도록 여기서 들고 있는다.
  final AdminPlayerController _player = AdminPlayerController();

  final List<Widget> _pages = const [
    AdminStudentTab(),
    AdminLaundryTab(),
    AdminReturnTab(),
    AdminNoticeTab(),
    AdminSongTab(),
  ];

  @override
  void dispose() {
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// 하단바로 이동할 때는 화면이 밀리는 애니메이션 없이 즉시 전환한다.
  void _goToPage(int index) => _pageController.jumpToPage(index);

  @override
  Widget build(BuildContext context) {
    // 상단바 뒤까지 body 를 확장하고, 페이지는 그만큼 내려 제자리에 오게 한다.
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return AdminPlayerScope(
      controller: _player,
      // 플레이어를 Scaffold 밖에 둔다. 안에 넣으면 상단바를 못 덮어서
      // 창이 올라온 상태에서도 프로필(마이페이지) 버튼이 눌린다.
      child: Stack(
        children: [
          _buildScaffold(context, topInset),
          Material(
            // Scaffold 밖이라 ListTile 등이 쓸 Material 조상이 없다.
            type: MaterialType.transparency,
            child: AnimatedBuilder(
              animation: _player,
              builder: (context, _) => AdminPlayerOverlay(controller: _player),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, double topInset) {
    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      extendBodyBehindAppBar: true,
      // 키보드가 올라와도 하단 네비게이션 바는 제자리에 둔다.
      resizeToAvoidBottomInset: false,
      appBar: const AppTopBar(),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topInset),
            // extendBodyBehindAppBar 가 남긴 상태바 패딩을 걷어낸다.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: PageView(
                controller: _pageController,
                // 화면 전환은 하단 네비게이션 바로만.
                physics: const NeverScrollableScrollPhysics(),
                children: [
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
