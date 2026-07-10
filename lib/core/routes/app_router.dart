import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/my_page/my_page_screen.dart';
import '../services/auth_service.dart';

const _protectedRoutes = {'/home', '/my'};

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    if (!_protectedRoutes.contains(state.matchedLocation)) return null;
    final token = await AuthService.getAccessToken();
    if (token == null) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: SplashScreen(),
      ),
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
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeScreen(),
      ),
    ),

    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: SignupScreen(),
      ),
    ),

    GoRoute(
      path: '/my',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: MyPageScreen(),
      ),
    ),
  ],
);