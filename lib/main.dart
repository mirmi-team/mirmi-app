import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 저장된 테마를 먼저 읽어야 첫 프레임부터 올바른 모드로 뜬다.
  await ThemeService.load();
  // 세로 방향 고정. 가로로 눕혀도 회전하지 않는다.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // 상태바·네비게이션바 색은 app.dart 의 AnnotatedRegion 이 테마에 맞춰 정한다.
  // 여기서 한 번 고정해두면 테마를 바꿔도 그대로 남는다.
  runApp(const MyApp());
}
