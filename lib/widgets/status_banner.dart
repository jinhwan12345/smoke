import 'package:flutter/material.dart';
import '../services/location_service.dart';

class StatusBanner extends StatelessWidget {
  final LocationCheckResult? checkResult;
  final VoidCallback? onTap;

  const StatusBanner({
    super.key,
    required this.checkResult,
    this.onTap,
  });

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

    // 배너 배경색, 아이콘, 텍스트 상태 분기
    final Color primaryColor;
    final String statusTitle;
    final String statusSubtitle;
    final String iconAsset;
    final IconData fallbackIcon;

    if (isInsideSmoking) {
      primaryColor = const Color(0xFF2E7D32); // 초록색 (안전 흡연 구역)
      statusTitle = '현재 흡연구역 내부입니다 🚬';
      statusSubtitle = currentSmoking?.name ?? '지정 흡연구역';
      iconAsset = 'assets/images/app_logo.png';
      fallbackIcon = Icons.smoking_rooms;
    } else if (isInsideNonSmoking) {
      primaryColor = const Color(0xFFC62828); // 붉은색 (경고 금연 구역)
      statusTitle = '현재 지정 금연구역 내부입니다 🚫';
      statusSubtitle = '${currentNonSmoking?.name ?? "지정 금연구역"} (흡연 시 과태료 부과)';
      iconAsset = 'assets/images/no_smoke.png';
      fallbackIcon = Icons.smoke_free;
    } else {
      primaryColor = const Color(0xFF334155); // 슬레이트 색상 (일반 구역)
      statusTitle = '현재 일반 구역(비흡연구역)입니다 🚶';
      if (nearestSmoking != null && distSmoking != double.infinity) {
        statusSubtitle = '가장 가까운 흡연구역: ${distSmoking.toInt()}m (${nearestSmoking.name})';
      } else {
        statusSubtitle = '주변에 등록된 흡연구역이 없습니다.';
      }
      iconAsset = 'assets/images/no_smoke.png';
      fallbackIcon = Icons.info_outline;
    }

    return Container(
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      iconAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        fallbackIcon,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusSubtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
