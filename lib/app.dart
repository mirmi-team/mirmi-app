import 'dart:io';
import 'package:flutter/material.dart';
import 'core/routes/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        if (!Platform.isAndroid) return child!;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(top: mq.padding.top + 10),
          ),
          child: child!,
        );
      },
    );
  }
}
