import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      // builder: (context, state) => const 페이지이름(),
    ),
  ],
);