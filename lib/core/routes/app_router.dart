import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';

final router = GoRouter(
  initialLocation: '/',
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
  ],
);