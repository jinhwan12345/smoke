import 'package:flutter/material.dart';

/// 대충 직직 그린 공책 낙서 / 손그림 UI 전용 컬러 & 스타일 팔레트
class SketchColors {
  // 종이 & 잉크 기본 톤
  static const Color paper = Color(0xFFFFFDF7);        // 따뜻한 스케치북 종이색
  static const Color paperWarm = Color(0xFFFEF7E5);    // 누런 메모지/포스트잇 크림색
  static const Color paperBlue = Color(0xFFF3F8FF);    // 연한 노트 줄/모눈 배경
  static const Color ink = Color(0xFF222222);          // 진한 검정 사인펜/볼펜 잉크
  static const Color inkMuted = Color(0xFF57534E);     // 연필심 진회색
  static const Color inkLight = Color(0xFF8C857B);     // 흐린 연필 메모색
  static const Color notebookLine = Color(0xFFD6E4F0); // 공책 연파랑 모눈선

  // 형광펜 & 색연필 포인트 컬러
  static const Color smokeYellow = Color(0xFFFFD166);  // 흡연구역 노랑/귤 형광펜
  static const Color smokeAmber = Color(0xFFD97706);   // 흡연구역 진주황 사인펜
  static const Color smokeFill = Color(0xFFFFF3CD);    // 흡연구역 연노랑 메모지

  static const Color noSmokeRed = Color(0xFFE63946);   // 금연구역 빨간 사인펜
  static const Color noSmokeFill = Color(0xFFFFE5E7);  // 금연구역 연빨강 메모지
  static const Color noSmokeDark = Color(0xFF9B1C26);  // 금연구역 진빨강 글씨

  static const Color safeGreen = Color(0xFF2A9D8F);    // 안전 흡연 초록 사인펜
  static const Color safeFill = Color(0xFFDFF7F2);     // 안전 흡연 연민트 메모지

  static const Color bluePen = Color(0xFF2B6CB0);      // 파란 볼펜 포인트
  static const Color blueFill = Color(0xFFE3F2FD);     // 파란 형광펜 채움

  static const Color tealPen = Color(0xFF0F766E);      // 청록 사인펜 (지번 배지)
  static const Color tapeColor = Color(0xCCFFE89E);    // 반투명 노란 마스킹 테이프
  static const Color tapePink = Color(0xCCFFC8DD);     // 반투명 핑크 마스킹 테이프
}

class SketchTextStyles {
  static const String fontFamily = 'Gaegu';

  static TextStyle title({
    double size = 24,
    Color color = SketchColors.ink,
    double height = 1.2,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: height,
      letterSpacing: 0.2,
    );
  }

  static TextStyle body({
    double size = 16,
    Color color = SketchColors.ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.3,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle label({
    double size = 15,
    Color color = SketchColors.ink,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.15,
    );
  }
}
