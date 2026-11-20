import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sketch_theme.dart';

/// 자 없이 펜으로 대충 직직 그린 삐뚤빼뚤 사각형 박스
class SketchBox extends StatelessWidget {
  final Widget child;
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final double strokeWidth;
  final double cornerRadius;
  final EdgeInsetsGeometry? padding;
  final Offset shadowOffset;
  final int seed;
  final double roughness;
  final bool doubleStroke;
  final bool showHatchShadow;
  final VoidCallback? onTap;

  const SketchBox({
    super.key,
    required this.child,
    this.fillColor = SketchColors.paper,
    this.borderColor = SketchColors.ink,
    this.shadowColor = SketchColors.ink,
    this.strokeWidth = 2.2,
    this.cornerRadius = 14.0,
    this.padding,
    this.shadowOffset = const Offset(3.5, 4.0),
    this.seed = 42,
    this.roughness = 1.8,
    this.doubleStroke = true,
    this.showHatchShadow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = CustomPaint(
      painter: _SketchBoxPainter(
        fillColor: fillColor,
        borderColor: borderColor,
        shadowColor: shadowColor,
        strokeWidth: strokeWidth,
        cornerRadius: cornerRadius,
        shadowOffset: shadowOffset,
        seed: seed,
        roughness: roughness,
        doubleStroke: doubleStroke,
        showHatchShadow: showHatchShadow,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: content,
        ),
      );
    }

    return content;
  }
}

class _SketchBoxPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final double strokeWidth;
  final double cornerRadius;
  final Offset shadowOffset;
  final int seed;
  final double roughness;
  final bool doubleStroke;
  final bool showHatchShadow;

  _SketchBoxPainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.shadowOffset,
    required this.seed,
    required this.roughness,
    required this.doubleStroke,
    required this.showHatchShadow,
  });

  Path _buildWobblyRectPath(Rect rect, math.Random rng, double amp) {
    final r = math.min(cornerRadius, math.min(rect.width, rect.height) * 0.45);
    double j() => (rng.nextDouble() - 0.5) * 2.0 * amp;

    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;

    final path = Path();
    // 시작점: 좌상단 모서리 끝
    path.moveTo(left + r + j(), top + j());

    // 상단 변 (3분할로 살짝 휘게)
    final topLen = math.max(1.0, right - left - 2 * r);
    path.quadraticBezierTo(
      left + r + topLen * 0.35,
      top + j() * 1.15,
      left + r + topLen * 0.65,
      top + j() * 0.8,
    );
    path.quadraticBezierTo(
      left + r + topLen * 0.85,
      top + j() * 1.0,
      right - r + j() * 0.6,
      top + j() * 0.7,
    );

    // 우상단 코너
    path.quadraticBezierTo(
      right + j() * 0.6,
      top + j() * 0.6,
      right + j() * 0.7,
      top + r + j() * 0.6,
    );

    // 우측 변
    final sideLen = math.max(1.0, bottom - top - 2 * r);
    path.quadraticBezierTo(
      right + j() * 1.1,
      top + r + sideLen * 0.5,
      right + j() * 0.7,
      bottom - r + j() * 0.6,
    );

    // 우하단 코너
    path.quadraticBezierTo(
      right + j() * 0.6,
      bottom + j() * 0.6,
      right - r + j() * 0.6,
      bottom + j() * 0.7,
    );

    // 하단 변
    path.quadraticBezierTo(
      right - r - topLen * 0.35,
      bottom + j() * 1.15,
      left + r + topLen * 0.35,
      bottom + j() * 0.8,
    );
    path.quadraticBezierTo(
      left + r + topLen * 0.15,
      bottom + j() * 0.9,
      left + r + j() * 0.6,
      bottom + j() * 0.7,
    );

    // 좌하단 코너
    path.quadraticBezierTo(
      left + j() * 0.6,
      bottom + j() * 0.6,
      left + j() * 0.7,
      bottom - r + j() * 0.6,
    );

    // 좌측 변
    path.quadraticBezierTo(
      left + j() * 1.1,
      bottom - r - sideLen * 0.5,
      left + j() * 0.7,
      top + r + j() * 0.6,
    );

    // 좌상단 코너 닫기
    path.quadraticBezierTo(
      left + j() * 0.6,
      top + j() * 0.6,
      left + r + j() * 0.5,
      top + j() * 0.5,
    );
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rng = math.Random(seed);

    // 1. 투박한 잉크 그림자 (또는 빗금 그림자)
    if (shadowOffset != Offset.zero) {
      final shadowRect = rect.shift(shadowOffset);
      final shadowPath = _buildWobblyRectPath(shadowRect, math.Random(seed + 7), roughness * 0.7);
      if (showHatchShadow) {
        canvas.save();
        canvas.clipPath(shadowPath);
        final hatchPaint = Paint()
          ..color = shadowColor.withOpacity(0.28)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;
        for (double x = -size.height; x < size.width + size.height; x += 6.5) {
          canvas.drawLine(
            Offset(shadowRect.left + x, shadowRect.top),
            Offset(shadowRect.left + x + size.height * 0.8, shadowRect.bottom),
            hatchPaint,
          );
        }
        canvas.restore();
      } else {
        final shadowPaint = Paint()
          ..color = shadowColor.withOpacity(0.85)
          ..style = PaintingStyle.fill;
        canvas.drawPath(shadowPath, shadowPaint);
      }
    }

    // 2. 종이/색연필 채우기
    final mainPath = _buildWobblyRectPath(rect, rng, roughness);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(mainPath, fillPaint);

    // 3. 첫 번째 사인펜 외곽선
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(mainPath, strokePaint);

    // 4. 대충 한 번 더 덧그린 얇은 보조 스케치선
    if (doubleStroke) {
      final secondPath = _buildWobblyRectPath(
        rect.deflate(0.4),
        math.Random(seed + 101),
        roughness * 1.15,
      );
      final secondPaint = Paint()
        ..color = borderColor.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(secondPath, secondPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchBoxPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.seed != seed;
  }
}

/// 손으로 한 바퀴 반 쓱 돌린 듯한 삐뚤빼뚤 원형 컨테이너 (마커, 나침반, FAB 버튼)
class SketchCircle extends StatelessWidget {
  final Widget child;
  final double size;
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final double strokeWidth;
  final Offset shadowOffset;
  final int seed;
  final VoidCallback? onTap;

  const SketchCircle({
    super.key,
    required this.child,
    required this.size,
    this.fillColor = SketchColors.paper,
    this.borderColor = SketchColors.ink,
    this.shadowColor = SketchColors.ink,
    this.strokeWidth = 2.2,
    this.shadowOffset = const Offset(2.5, 3.0),
    this.seed = 13,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget circle = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SketchCirclePainter(
          fillColor: fillColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          strokeWidth: strokeWidth,
          shadowOffset: shadowOffset,
          seed: seed,
        ),
        child: Center(child: child),
      ),
    );

    if (onTap != null) {
      circle = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: circle,
        ),
      );
    }

    return circle;
  }
}

class _SketchCirclePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final double strokeWidth;
  final Offset shadowOffset;
  final int seed;

  _SketchCirclePainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.strokeWidth,
    required this.shadowOffset,
    required this.seed,
  });

  Path _buildWobblyCircle(Offset center, double radius, int s, {double extraTurns = 0.08}) {
    final rng = math.Random(s);
    const segments = 18;
    final totalAngle = math.pi * 2 * (1.0 + extraTurns);
    final points = <Offset>[];
    final amp = math.max(1.0, radius * 0.065);

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = t * totalAngle + (s % 5) * 0.4;
      final r = radius + (rng.nextDouble() - 0.5) * 2 * amp;
      points.add(Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;

    if (shadowOffset != Offset.zero) {
      final shadowPaint = Paint()
        ..color = shadowColor.withOpacity(0.82)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center + shadowOffset, radius, shadowPaint);
    }

    // 배경 원 (약간 삐뚤빼뚤 채우기)
    final fillPath = _buildWobblyCircle(center, radius, seed, extraTurns: 0.0);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    // 1차 사인펜 외곽선 (살짝 겹치게 한 바퀴 + α)
    final outerStroke = _buildWobblyCircle(center, radius, seed, extraTurns: 0.14);
    canvas.drawPath(
      outerStroke,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 2차 연한 덧그리기 선
    final innerStroke = _buildWobblyCircle(center, radius - 0.6, seed + 53, extraTurns: 0.05);
    canvas.drawPath(
      innerStroke,
      Paint()
        ..color = borderColor.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SketchCirclePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.seed != seed;
  }
}

/// 누르면 살짝 들어가는 손그림 버튼
class SketchButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color fillColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final double cornerRadius;
  final int seed;

  const SketchButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.fillColor = SketchColors.smokeYellow,
    this.borderColor = SketchColors.ink,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.cornerRadius = 14,
    this.seed = 21,
  });

  @override
  State<SketchButton> createState() => _SketchButtonState();
}

class _SketchButtonState extends State<SketchButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(
            _pressed ? 2.5 : 0,
            _pressed ? 3.0 : 0,
            0,
          ),
          child: SketchBox(
            fillColor: enabled ? widget.fillColor : const Color(0xFFE5E5E5),
            borderColor: widget.borderColor,
            shadowColor: widget.borderColor,
            shadowOffset: _pressed ? const Offset(1.0, 1.0) : const Offset(3.5, 4.0),
            cornerRadius: widget.cornerRadius,
            padding: widget.padding,
            seed: widget.seed,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 글자 뒤에 형광펜으로 쓱 그은 듯한 강조 위젯
class HighlighterText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color highlightColor;
  final TextAlign textAlign;

  const HighlighterText({
    super.key,
    required this.text,
    required this.style,
    this.highlightColor = SketchColors.smokeYellow,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HighlighterPainter(color: highlightColor),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          textAlign: textAlign,
          style: style,
        ),
      ),
    );
  }
}

class _HighlighterPainter extends CustomPainter {
  final Color color;

  _HighlighterPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.54,
        size.width - 1,
        size.height * 0.60,
      )
      ..lineTo(size.width - 4, size.height * 0.96)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.90,
        0,
        size.height * 0.94,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.75)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HighlighterPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 메모지 위에 살짝 붙여놓은 반투명 마스킹 테이프 장식
class MaskingTape extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double angle;

  const MaskingTape({
    super.key,
    this.width = 76,
    this.height = 20,
    this.color = SketchColors.tapeColor,
    this.angle = -0.05,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: Size(width, height),
        painter: _MaskingTapePainter(color: color),
      ),
    );
  }
}

class _MaskingTapePainter extends CustomPainter {
  final Color color;

  _MaskingTapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(3, 1)
      ..lineTo(size.width - 2, 0)
      ..lineTo(size.width - 5, size.height * 0.35)
      ..lineTo(size.width, size.height * 0.65)
      ..lineTo(size.width - 3, size.height)
      ..lineTo(2, size.height - 1)
      ..lineTo(5, size.height * 0.55)
      ..lineTo(0, size.height * 0.25)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = SketchColors.ink.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _MaskingTapePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 삐뚤빼뚤 연필 구분선
class SketchDivider extends StatelessWidget {
  final Color color;
  final double height;
  final int seed;

  const SketchDivider({
    super.key,
    this.color = SketchColors.inkLight,
    this.height = 10,
    this.seed = 7,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SketchDividerPainter(color: color, seed: seed),
      ),
    );
  }
}

class _SketchDividerPainter extends CustomPainter {
  final Color color;
  final int seed;

  _SketchDividerPainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final midY = size.height / 2;
    final path = Path()..moveTo(0, midY);
    const steps = 14;
    for (int i = 1; i <= steps; i++) {
      final x = size.width * (i / steps);
      final y = midY + (rng.nextDouble() - 0.5) * 3.0;
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SketchDividerPainter oldDelegate) => false;
}

/// 스플래시 화면 & 바텀시트용 공책 모눈 종이 배경 + 연필 낙서 장식
class NotebookPaperBackground extends StatelessWidget {
  final Widget child;
  final bool showMarginLine;
  final bool showDoodles;

  const NotebookPaperBackground({
    super.key,
    required this.child,
    this.showMarginLine = true,
    this.showDoodles = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotebookPaperPainter(
        showMarginLine: showMarginLine,
        showDoodles: showDoodles,
      ),
      child: child,
    );
  }
}

class _NotebookPaperPainter extends CustomPainter {
  final bool showMarginLine;
  final bool showDoodles;

  _NotebookPaperPainter({
    required this.showMarginLine,
    required this.showDoodles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 따뜻한 공책 종이 바탕
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = SketchColors.paper,
    );

    // 모눈종이 가로/세로 연파랑 선
    final gridPaint = Paint()
      ..color = SketchColors.notebookLine.withOpacity(0.55)
      ..strokeWidth = 1.0;

    const spacing = 26.0;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 왼쪽 빨간 노트 여백선
    if (showMarginLine) {
      final marginPaint = Paint()
        ..color = SketchColors.noSmokeRed.withOpacity(0.22)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(32, 0), Offset(32, size.height), marginPaint);
    }

    // 구석에 대충 쓱싹 그린 연필 낙서(별, 연기 꼬불이, 화살표)
    if (showDoodles) {
      final doodlePaint = Paint()
        ..color = SketchColors.ink.withOpacity(0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // 우상단 꼬불꼬불 별 낙서
      _drawStarDoodle(canvas, Offset(size.width - 42, 66), 12, doodlePaint);
      // 좌하단 꼬불꼬불 연기 선
      final squiggle = Path()
        ..moveTo(46, size.height - 120)
        ..quadraticBezierTo(30, size.height - 135, 50, size.height - 150)
        ..quadraticBezierTo(68, size.height - 165, 44, size.height - 180);
      canvas.drawPath(squiggle, doodlePaint);

      // 우하단 작은 빗금 세 줄
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(size.width - 54 + i * 8, size.height - 86),
          Offset(size.width - 44 + i * 8, size.height - 102),
          doodlePaint,
        );
      }
    }
  }

  void _drawStarDoodle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.65, c.dy + r * 0.85)
      ..lineTo(c.dx - r * 0.9, c.dy - r * 0.25)
      ..lineTo(c.dx + r * 0.9, c.dy - r * 0.25)
      ..lineTo(c.dx - r * 0.65, c.dy + r * 0.85)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotebookPaperPainter oldDelegate) => false;
}

/// 자 없이 대충 그린 손그림 아이콘들 (+, -, 내위치, 체크, 복사 등)
enum SketchGlyph { plus, minus, target, check, copy, warning, touch }

class SketchIcon extends StatelessWidget {
  final SketchGlyph glyph;
  final double size;
  final Color color;
  final double strokeWidth;

  const SketchIcon({
    super.key,
    required this.glyph,
    this.size = 22,
    this.color = SketchColors.ink,
    this.strokeWidth = 2.4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SketchGlyphPainter(
        glyph: glyph,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _SketchGlyphPainter extends CustomPainter {
  final SketchGlyph glyph;
  final Color color;
  final double strokeWidth;

  _SketchGlyphPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    switch (glyph) {
      case SketchGlyph.plus:
        // 대충 직직 그린 +
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.2, h * 0.52)
            ..quadraticBezierTo(w * 0.5, h * 0.47, w * 0.82, h * 0.51),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.49, h * 0.18)
            ..quadraticBezierTo(w * 0.53, h * 0.5, w * 0.48, h * 0.82),
          p,
        );
        break;

      case SketchGlyph.minus:
        // 대충 직직 그린 -
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.2, h * 0.51)
            ..quadraticBezierTo(w * 0.5, h * 0.47, w * 0.82, h * 0.53),
          p,
        );
        break;

      case SketchGlyph.target:
        // 대충 그린 조준점 (내 위치)
        canvas.drawOval(
          Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.52, height: h * 0.48),
          p,
        );
        canvas.drawCircle(
          Offset(w * 0.51, h * 0.5),
          w * 0.08,
          Paint()..color = color..style = PaintingStyle.fill,
        );
        canvas.drawLine(Offset(w * 0.5, h * 0.08), Offset(w * 0.49, h * 0.26), p);
        canvas.drawLine(Offset(w * 0.51, h * 0.74), Offset(w * 0.5, h * 0.92), p);
        canvas.drawLine(Offset(w * 0.08, h * 0.51), Offset(w * 0.25, h * 0.49), p);
        canvas.drawLine(Offset(w * 0.75, h * 0.51), Offset(w * 0.92, h * 0.5), p);
        break;

      case SketchGlyph.check:
        // 쓱싹 체크 표시
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.18, h * 0.54)
            ..lineTo(w * 0.42, h * 0.78)
            ..quadraticBezierTo(w * 0.62, h * 0.48, w * 0.86, h * 0.22),
          p,
        );
        break;

      case SketchGlyph.copy:
        // 손그림 메모지 2장 겹친 복사 아이콘
        final back = Path()
          ..moveTo(w * 0.32, h * 0.28)
          ..lineTo(w * 0.34, h * 0.14)
          ..lineTo(w * 0.84, h * 0.16)
          ..lineTo(w * 0.82, h * 0.70)
          ..lineTo(w * 0.68, h * 0.70);
        canvas.drawPath(back, p..strokeWidth = strokeWidth * 0.85);
        final front = Path()
          ..moveTo(w * 0.16, h * 0.32)
          ..lineTo(w * 0.66, h * 0.30)
          ..lineTo(w * 0.68, h * 0.86)
          ..lineTo(w * 0.18, h * 0.84)
          ..close();
        canvas.drawPath(front, p);
        break;

      case SketchGlyph.warning:
        // 삐뚤빼뚤 세모 + 느낌표
        final tri = Path()
          ..moveTo(w * 0.5, h * 0.12)
          ..lineTo(w * 0.89, h * 0.84)
          ..lineTo(w * 0.12, h * 0.86)
          ..close();
        canvas.drawPath(tri, p);
        canvas.drawLine(Offset(w * 0.5, h * 0.38), Offset(w * 0.49, h * 0.62), p);
        canvas.drawCircle(
          Offset(w * 0.5, h * 0.74),
          strokeWidth * 0.55,
          Paint()..color = color..style = PaintingStyle.fill,
        );
        break;

      case SketchGlyph.touch:
        // 손그림 화살표/반짝이 포인터
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.22, h * 0.22)
            ..lineTo(w * 0.78, h * 0.52)
            ..lineTo(w * 0.52, h * 0.58)
            ..lineTo(w * 0.44, h * 0.84)
            ..close(),
          p,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SketchGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
