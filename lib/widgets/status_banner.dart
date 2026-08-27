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

    final isInside = checkResult!.isInsideSmokingArea;
    final currentArea = checkResult!.currentArea;
    final nearestArea = checkResult!.nearestArea;
    final distance = checkResult!.distanceToNearest;

    final primaryColor = isInside ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final statusTitle = isInside ? '현재 흡연구역 내부입니다 🚬' : '현재 금연구역(비흡연구역)입니다 🚫';

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
                      isInside
                          ? 'assets/images/app_logo.png'
                          : 'assets/images/no_smoke.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        isInside ? Icons.smoking_rooms : Icons.smoke_free,
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
                      if (isInside && currentArea != null)
                        Text(
                          currentArea.name,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (!isInside && nearestArea != null)
                        Text(
                          '가장 가까운 흡연구역: ${distance.toInt()}m (${nearestArea.name})',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        const Text(
                          '주변에 등록된 흡연구역이 없습니다.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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

