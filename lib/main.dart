import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/sketch_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmokeFinderApp());
}

class SmokeFinderApp extends StatelessWidget {
  const SmokeFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '담뱃불좀꺼줄래',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: SketchColors.smokeAmber,
          primary: SketchColors.ink,
          surface: SketchColors.paper,
        ),
        scaffoldBackgroundColor: SketchColors.paper,
        useMaterial3: true,
        fontFamily: SketchTextStyles.fontFamily,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: SketchColors.ink,
          contentTextStyle: SketchTextStyles.body(
            size: 16,
            color: SketchColors.paper,
            weight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: SketchColors.smokeYellow, width: 2),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
