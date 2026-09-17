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
          scaffoldBackgroundColor: AppDark.bgCanvas,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppBrand.primary,
            selectionColor: Color(0x5506B6D4),
            selectionHandleColor: AppBrand.primary,
          ),
        ),
        builder: (context, child) {
          Widget result = child!;
          final mq = MediaQuery.of(context);

          // 키보드 높이(viewInsets)는 건드리지 않는다. 0으로 덮으면 Scaffold가
          // 리사이즈되지 않아 입력창이 키보드에 가려진다.
          // 하단 버튼을 고정해야 하는 화면은 그 Scaffold 에서
          // resizeToAvoidBottomInset: false 로 개별 처리한다.
          var data = mq;

          if (Platform.isAndroid) {
            data = data.copyWith(
              padding: data.padding.copyWith(top: data.padding.top + 10),
            );
          }

          result = MediaQuery(data: data, child: result);
          final isDark =
              MediaQuery.platformBrightnessOf(context) == Brightness.dark;
          result = AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: result,
          );
          return result;
        },
      ),
    );
  }
}
