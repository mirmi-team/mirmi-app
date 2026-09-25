import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/my_page/my_page_screen.dart';
import '../../features/my_page/delete_account_screen.dart';
import '../../features/my_page/logout_screen.dart';
import '../../features/my_page/change_password_screen.dart';
import '../../features/my_page/merit_log_screen.dart';
import '../../features/my_page/my_suggestions_screen.dart';
import '../../features/my_page/suggestion_detail_screen.dart';
import '../services/suggestion_service.dart';
import '../../features/my_page/inquiry_screen.dart';
import '../../features/notice/notice_detail_screen.dart';
import '../services/notice_service.dart';
import '../services/auth_service.dart';

const _protectedRoutes = {'/home', '/admin', '/my'};

/// 시트나 다이얼로그가 닫히면 Flutter 가 이전 화면의 포커스를 되살린다.
/// 텍스트 필드에 포커스가 남아 있었다면 키보드가 저절로 올라오므로 여기서 해제한다.
/// (닫힘 애니메이션이 끝난 뒤 복원되므로 다음 프레임에 처리한다)
class _UnfocusOnPop extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}

final router = GoRouter(
  initialLocation: '/',
  observers: [_UnfocusOnPop()],
  redirect: (context, state) async {
    if (!_protectedRoutes.contains(state.matchedLocation)) return null;
    final token = await AuthService.getAccessToken();
    if (token == null) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: SplashScreen()),
    ),

    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.extra ?? 'login'),
        child: LoginScreen(successMessage: state.extra as String?),
      ),
    ),

    GoRoute(
      path: '/home',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: HomeScreen()),
    ),

    GoRoute(
      path: '/admin',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: AdminScreen()),
    ),

    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: SignupScreen()),
    ),

    GoRoute(
      path: '/my',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: MyPageScreen()),
    ),

    GoRoute(
      path: '/delete-account',
      pageBuilder: (context, state) =>
          const MaterialPage(child: DeleteAccountScreen()),
    ),

    GoRoute(
      path: '/logout',
      pageBuilder: (context, state) =>
          const MaterialPage(child: LogoutScreen()),
    ),

    GoRoute(
      path: '/change-password',
      pageBuilder: (context, state) =>
          const MaterialPage(child: ChangePasswordScreen()),
    ),

    GoRoute(
      path: '/merit-logs',
      pageBuilder: (context, state) =>
          const MaterialPage(child: MeritLogScreen()),
    ),

    GoRoute(
      path: '/my-suggestions',
      pageBuilder: (context, state) =>
          const MaterialPage(child: MySuggestionsScreen()),
    ),

    GoRoute(
      path: '/suggestion-detail',
      pageBuilder: (context, state) => MaterialPage(
        child: SuggestionDetailScreen(suggestion: state.extra as Suggestion),
      ),
    ),

    GoRoute(
      path: '/notice-detail',
      pageBuilder: (context, state) => MaterialPage(
        child: NoticeDetailScreen(notice: state.extra as Notice),
      ),
    ),

    GoRoute(
      path: '/inquiry',
      pageBuilder: (context, state) =>
          const MaterialPage(child: InquiryScreen()),
    ),
  ],
);
