import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/routes/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        Widget result = child!;
        if (Platform.isAndroid) {
          final mq = MediaQuery.of(context);
          result = MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(top: mq.padding.top + 10),
            ),
            child: result,
          );
          result = AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: result,
          );
        }
        return result;
      },
    );
  }
}
