import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

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
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const MapScreen(),
    );
  }
}
