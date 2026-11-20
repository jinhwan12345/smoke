import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/smoking_area_service.dart';
import '../theme/sketch_theme.dart';
import '../widgets/sketch_widgets.dart';
import 'map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final String _statusText = '현재 위치를 찾는 중...';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();

    // 위치 권한 및 현재 위치 확인
    await LocationService.requestLocationPermission();
    Position initialPos = await LocationService.getCurrentPosition();

    // 스플래시 표시 최소 대기 시간(2.2초) 동안 내 주변 구역 및 전국 시·군·구 카운트 사전 로딩
    final preloadFuture = SmokingAreaService().preloadInitialData(
      userLat: initialPos.latitude,
      userLng: initialPos.longitude,
    );

    final elapsed = DateTime.now().difference(startTime);
    const minDisplayDuration = Duration(milliseconds: 2200);
    if (elapsed < minDisplayDuration) {
      await Future.delayed(minDisplayDuration - elapsed);
    }

    // 사전 로딩이 거의 끝났다면 최대 400ms까지만 더 기다린 뒤 즉시 진입
    await preloadFuture.timeout(
      const Duration(milliseconds: 400),
      onTimeout: () {},
    );

    if (!mounted) return;

    // 메인 지도 화면으로 부드럽게 전환
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) => MapScreen(
          initialPosition: initialPos,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SketchColors.paper,
      body: NotebookPaperBackground(
        showMarginLine: false,
        showDoodles: true,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 8),

                      // 상단: 손그림 로고 및 손글씨 타이틀
                      Column(
                        children: [
                          Transform.rotate(
                            angle: -0.04,
                            child: SketchCircle(
                              size: 108,
                              fillColor: SketchColors.smokeFill,
                              borderColor: SketchColors.ink,
                              strokeWidth: 2.6,
                              shadowOffset: const Offset(4, 5),
                              seed: 11,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Image.asset(
                                  'assets/images/doodle_smoke.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.smoking_rooms,
                                    size: 46,
                                    color: SketchColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          HighlighterText(
                            text: '담뱃불좀꺼줄래',
                            highlightColor: SketchColors.smokeYellow,
                            style: SketchTextStyles.title(
                              size: 36,
                              color: SketchColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '내 주변 흡연·금연구역 지도',
                            style: SketchTextStyles.body(
                              size: 18,
                              color: SketchColors.inkMuted,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      // 중앙: 마스킹테이프가 붙은 흡연 경고 메모지 카드
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Transform.rotate(
                            angle: 0.008,
                            child: SketchBox(
                              fillColor: SketchColors.noSmokeFill,
                              borderColor: SketchColors.noSmokeRed,
                              shadowColor: SketchColors.ink,
                              strokeWidth: 2.4,
                              cornerRadius: 18,
                              shadowOffset: const Offset(4, 5),
                              showHatchShadow: true,
                              seed: 33,
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: Image.asset(
                                          'assets/images/doodle_warning.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const SketchIcon(
                                            glyph: SketchGlyph.warning,
                                            size: 36,
                                            color: SketchColors.noSmokeRed,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '잠깐! 건강 경고!',
                                              style: SketchTextStyles.title(
                                                size: 22,
                                                color: SketchColors.noSmokeRed,
                                              ),
                                            ),
                                            Text(
                                              '금연 및 간접흡연 주의',
                                              style: SketchTextStyles.body(
                                                size: 14,
                                                color: SketchColors.noSmokeDark,
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const SketchDivider(
                                    color: SketchColors.noSmokeRed,
                                    seed: 19,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '흡연은 폐암, 뇌졸중, 심혈관 질환 등\n각종 치명적인 질병의 주요 원인이 됩니다.',
                                    textAlign: TextAlign.center,
                                    style: SketchTextStyles.body(
                                      size: 16.5,
                                      color: SketchColors.ink,
                                      weight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '비흡연자의 간접흡연 피해를 예방하기 위해\n반드시 지정된 흡연구역에서만 흡연해 주세요.',
                                    textAlign: TextAlign.center,
                                    style: SketchTextStyles.body(
                                      size: 15,
                                      color: SketchColors.inkMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SketchBox(
                                    fillColor: SketchColors.paper,
                                    borderColor: SketchColors.ink,
                                    shadowOffset: const Offset(2, 2.5),
                                    strokeWidth: 1.8,
                                    cornerRadius: 16,
                                    doubleStroke: false,
                                    seed: 47,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      '금연상담전화 : 국번없이 1544-9030',
                                      style: SketchTextStyles.label(
                                        size: 15.5,
                                        color: SketchColors.smokeAmber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Positioned(
                            top: -11,
                            child: MaskingTape(
                              width: 88,
                              height: 22,
                              color: SketchColors.tapeColor,
                              angle: -0.04,
                            ),
                          ),
                        ],
                      ),

                      // 하단: 로딩 상태
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: SketchColors.ink,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _statusText,
                              style: SketchTextStyles.body(
                                size: 17,
                                color: SketchColors.ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
