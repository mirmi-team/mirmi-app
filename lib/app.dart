import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/routes/app_router.dart';
import 'shared/app_colors.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        // brightness가 TextField의 keyboardAppearance 기본값이 된다.
        // dark로 두면 iOS 키보드가 다크 테마로 뜬다. (Android는 시스템 IME가 결정)
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.backB,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppColors.mainColor,
            selectionColor: Color(0x5506B6D4),
            selectionHandleColor: AppColors.mainColor,
          ),
        ),
        builder: (context, child) {
          Widget result = child!;
          final mq = MediaQuery.of(context);

          // 키보드가 올라와도 하단 버튼이 밀리지 않도록 전역 처리.
          // - viewInsets를 0으로 → Scaffold가 키보드만큼 리사이즈되지 않음
          // - padding.bottom을 viewPadding.bottom으로 고정 → 키보드가 홈 인디케이터를
          //   가려도 SafeArea가 소비하는 하단 여백이 그대로 유지됨
          var data = mq.copyWith(
            viewInsets: mq.viewInsets.copyWith(bottom: 0),
            padding: mq.padding.copyWith(bottom: mq.viewPadding.bottom),
          );

          if (Platform.isAndroid) {
            data = data.copyWith(
              padding: data.padding.copyWith(top: data.padding.top + 10),
            );
          }

          result = MediaQuery(data: data, child: result);
          final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
          result = AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
            child: result,
          );
          return result;
        },
      ),
    );
  }
}
