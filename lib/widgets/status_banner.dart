import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/sketch_theme.dart';
import 'sketch_widgets.dart';

class StatusBanner extends StatelessWidget {
  final LocationCheckResult? checkResult;
  final VoidCallback? onTap;

  const StatusBanner({
    super.key,
    required this.checkResult,
    this.onTap,
  });

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.toInt()}m';
  }

  @override
  Widget build(BuildContext context) {
    if (checkResult == null) {
      return const SizedBox.shrink();
    }

    final isInsideSmoking = checkResult!.isInsideSmokingArea;
    final isInsideNonSmoking = checkResult!.isInsideNonSmokingArea;
    final currentSmoking = checkResult!.currentSmokingArea;
    final currentNonSmoking = checkResult!.currentNonSmokingArea;
    final nearestSmoking = checkResult!.nearestSmokingArea;
    final distSmoking = checkResult!.distanceToNearestSmoking;

    final Color paperColor;
    final Color accentColor;
    final String statusTitle;
    final String statusSubtitle;
    final String iconAsset;
    final IconData fallbackIcon;
    final bool hasTarget;

    if (isInsideSmoking) {
      paperColor = SketchColors.safeFill;
      accentColor = SketchColors.safeGreen;
      statusTitle = '여긴 흡연구역 내부예요!';
      statusSubtitle = currentSmoking?.name ?? '지정 흡연구역';
      iconAsset = 'assets/images/doodle_smoke.png';
      fallbackIcon = Icons.smoking_rooms;
      hasTarget = currentSmoking != null;
    } else if (isInsideNonSmoking) {
      paperColor = SketchColors.noSmokeFill;
      accentColor = SketchColors.noSmokeRed;
      statusTitle = '잠깐! 지정 금연구역이에요!';
      statusSubtitle = '${currentNonSmoking?.name ?? "지정 금연구역"} (과태료 주의)';
      iconAsset = 'assets/images/doodle_no_smoke.png';
      fallbackIcon = Icons.smoke_free;
      hasTarget = currentNonSmoking != null;
    } else {
      paperColor = SketchColors.paperWarm;
      accentColor = SketchColors.ink;
      statusTitle = '현재 일반 구역이에요';
      if (nearestSmoking != null && distSmoking != double.infinity) {
        statusSubtitle =
            '내 주변 가까운 흡연구역: ${_formatDistance(distSmoking)} (${nearestSmoking.name})';
        hasTarget = true;
      } else {
        statusSubtitle = '내 주변에 등록된 흡연구역이 없어요';
        hasTarget = false;
      }
      iconAsset = 'assets/images/doodle_walker.png';
      fallbackIcon = Icons.directions_walk;
    }

    return SketchBox(
      fillColor: paperColor,
      borderColor: accentColor,
      shadowColor: SketchColors.ink,
      strokeWidth: 2.4,
      cornerRadius: 16,
      shadowOffset: const Offset(3.5, 4.5),
      seed: 17,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SketchCircle(
            size: 50,
            fillColor: SketchColors.paper,
            borderColor: accentColor,
            strokeWidth: 2.0,
            shadowOffset: const Offset(1.5, 2.0),
            seed: 29,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  fallbackIcon,
                  color: accentColor,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SketchTextStyles.title(
                    size: 19.5,
                    color: isInsideNonSmoking
                        ? SketchColors.noSmokeDark
                        : isInsideSmoking
                            ? const Color(0xFF14532D)
                            : SketchColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SketchTextStyles.body(
                    size: 14.5,
                    color: SketchColors.inkMuted,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (hasTarget) ...[
            const SizedBox(width: 6),
            Text(
              '→',
              style: SketchTextStyles.title(
                size: 20,
                color: accentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
