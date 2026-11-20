import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/smoking_area.dart';
import '../theme/sketch_theme.dart';
import 'sketch_widgets.dart';

class AreaDetailSheet extends StatelessWidget {
  final SmokingArea area;
  final double? distanceInMeters;

  const AreaDetailSheet({
    super.key,
    required this.area,
    this.distanceInMeters,
  });

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.toInt()}m';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label(이)가 클립보드에 복사됐어요!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNonSmoking = area.isNonSmoking;
    final roadAddr = area.hasRoadAddress ? area.roadAddress : '도로명주소 정보 없음';
    final lotAddr = area.hasLotAddress ? area.lotAddress : '지번주소 정보 없음';

    final themeColor = isNonSmoking ? SketchColors.noSmokeRed : SketchColors.smokeAmber;
    final badgeFill = isNonSmoking ? SketchColors.noSmokeFill : SketchColors.smokeFill;
    final iconAsset = isNonSmoking
        ? 'assets/images/doodle_no_smoke.png'
        : 'assets/images/doodle_smoke.png';
    final fallbackIcon = isNonSmoking ? Icons.smoke_free : Icons.smoking_rooms;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: const BoxDecoration(
            color: SketchColors.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: SketchColors.ink, width: 2.8),
              left: BorderSide(color: SketchColors.ink, width: 2.8),
              right: BorderSide(color: SketchColors.ink, width: 2.8),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: NotebookPaperBackground(
              showMarginLine: false,
              showDoodles: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 대충 그린 드래그 핸들
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: SketchColors.ink.withOpacity(0.28),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 제목 및 구역 타입 스티커
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SketchCircle(
                              size: 46,
                              fillColor: SketchColors.paper,
                              borderColor: themeColor,
                              strokeWidth: 2.2,
                              shadowOffset: const Offset(2, 2.5),
                              seed: area.id.hashCode,
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Image.asset(
                                  iconAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    fallbackIcon,
                                    color: themeColor,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                area.name,
                                style: SketchTextStyles.title(
                                  size: 22,
                                  color: SketchColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.rotate(
                              angle: 0.03,
                              child: SketchBox(
                                fillColor: badgeFill,
                                borderColor: themeColor,
                                shadowColor: SketchColors.ink,
                                shadowOffset: const Offset(2, 2.5),
                                strokeWidth: 1.8,
                                cornerRadius: 14,
                                doubleStroke: false,
                                seed: 61,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  isNonSmoking ? '금연구역' : '흡연구역',
                                  style: SketchTextStyles.label(
                                    size: 14.5,
                                    color: isNonSmoking
                                        ? SketchColors.noSmokeDark
                                        : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 금연구역 경고 메모 박스
                        if (isNonSmoking)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SketchBox(
                              fillColor: SketchColors.noSmokeFill,
                              borderColor: SketchColors.noSmokeRed,
                              shadowColor: SketchColors.noSmokeRed,
                              shadowOffset: const Offset(2.5, 3),
                              showHatchShadow: true,
                              strokeWidth: 2.0,
                              cornerRadius: 14,
                              seed: 71,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const SketchIcon(
                                    glyph: SketchGlyph.warning,
                                    size: 24,
                                    color: SketchColors.noSmokeRed,
                                    strokeWidth: 2.2,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '여기는 지정 금연구역이에요! 흡연 시 과태료(최대 10만원)가 부과될 수 있어요.',
                                      style: SketchTextStyles.body(
                                        size: 15,
                                        color: SketchColors.noSmokeDark,
                                        weight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // 1. 도로명 주소 메모 카드
                        if (area.hasRoadAddress || !area.hasLotAddress)
                          _buildAddressCard(
                            context: context,
                            badgeLabel: '도로명',
                            badgeColor: SketchColors.blueFill,
                            badgeBorderColor: SketchColors.bluePen,
                            address: roadAddr,
                            canCopy: area.hasRoadAddress,
                            copyLabel: '도로명주소',
                            seed: 81,
                          ),

                        if (area.hasRoadAddress && area.hasLotAddress)
                          const SizedBox(height: 8),

                        // 2. 지번 주소 메모 카드
                        if (area.hasLotAddress)
                          _buildAddressCard(
                            context: context,
                            badgeLabel: '지번',
                            badgeColor: SketchColors.safeFill,
                            badgeBorderColor: SketchColors.tealPen,
                            address: lotAddr,
                            canCopy: true,
                            copyLabel: '지번주소',
                            seed: 82,
                          ),

                        const SizedBox(height: 12),
                        const SketchDivider(seed: 93),
                        const SizedBox(height: 8),

                        // 거리 & 반경 & 면적 & 기준일자 (Wrap으로 오버플로우 방지)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (distanceInMeters != null)
                              HighlighterText(
                                text: '${_formatDistance(distanceInMeters!)} 거리',
                                highlightColor: SketchColors.smokeYellow,
                                style: SketchTextStyles.label(
                                  size: 17,
                                  color: SketchColors.ink,
                                ),
                              ),
                            Text(
                              '• 유효 반경 ${area.radius.toInt()}m',
                              style: SketchTextStyles.body(
                                size: 15.5,
                                color: SketchColors.ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                            if (area.areaAr > 0)
                              Text(
                                '(${area.areaAr.toInt()}㎡)',
                                style: SketchTextStyles.body(
                                  size: 14.5,
                                  color: SketchColors.inkMuted,
                                ),
                              ),
                            if (area.refDate.isNotEmpty)
                              Text(
                                '· 기준일 ${area.refDate}',
                                style: SketchTextStyles.body(
                                  size: 14,
                                  color: SketchColors.inkLight,
                                ),
                              ),
                          ],
                        ),

                        // 공공데이터 출처
                        if (isNonSmoking) ...[
                          const SizedBox(height: 12),
                          SketchBox(
                            fillColor: SketchColors.paperWarm,
                            borderColor: SketchColors.inkLight,
                            shadowOffset: Offset.zero,
                            strokeWidth: 1.3,
                            cornerRadius: 10,
                            doubleStroke: false,
                            seed: 99,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/images/kogl_type1.png',
                                  height: 20,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '출처: 공공데이터포털 전국금연구역표준데이터 (공공누리 제1유형: 출처표시)',
                                    style: SketchTextStyles.body(
                                      size: 12.5,
                                      color: SketchColors.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // 확인 손그림 버튼
                        SizedBox(
                          width: double.infinity,
                          child: SketchButton(
                            fillColor: SketchColors.smokeYellow,
                            borderColor: SketchColors.ink,
                            seed: 55,
                            onPressed: () => Navigator.pop(context),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SketchIcon(
                                  glyph: SketchGlyph.check,
                                  size: 20,
                                  color: SketchColors.ink,
                                  strokeWidth: 2.6,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '확인했어요!',
                                  style: SketchTextStyles.title(
                                    size: 20,
                                    color: SketchColors.ink,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildAddressCard({
    required BuildContext context,
    required String badgeLabel,
    required Color badgeColor,
    required Color badgeBorderColor,
    required String address,
    required bool canCopy,
    required String copyLabel,
    required int seed,
  }) {
    return SketchBox(
      fillColor: SketchColors.paper,
      borderColor: SketchColors.ink,
      shadowOffset: const Offset(2, 2.5),
      strokeWidth: 1.7,
      cornerRadius: 12,
      doubleStroke: false,
      seed: seed,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SketchBox(
            fillColor: badgeColor,
            borderColor: badgeBorderColor,
            shadowOffset: Offset.zero,
            strokeWidth: 1.5,
            cornerRadius: 8,
            doubleStroke: false,
            seed: seed + 5,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              badgeLabel,
              style: SketchTextStyles.label(
                size: 13.5,
                color: badgeBorderColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address,
              style: SketchTextStyles.body(
                size: 15.5,
                color: canCopy ? SketchColors.ink : SketchColors.inkLight,
                weight: FontWeight.w700,
              ),
            ),
          ),
          if (canCopy)
            Tooltip(
              message: '$copyLabel 복사',
              child: GestureDetector(
                onTap: () => _copyToClipboard(context, address, copyLabel),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: const SketchIcon(
                      glyph: SketchGlyph.copy,
                      size: 18,
                      color: SketchColors.inkMuted,
                      strokeWidth: 2.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
