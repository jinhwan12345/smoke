import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/smoking_area.dart';

class AreaDetailSheet extends StatelessWidget {
  final SmokingArea area;
  final double? distanceInMeters;

  const AreaDetailSheet({
    super.key,
    required this.area,
    this.distanceInMeters,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label(이)가 클립보드에 복사되었습니다.'),
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

    final themeColor = isNonSmoking ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final iconAsset = isNonSmoking ? 'assets/images/no_smoke.png' : 'assets/images/app_logo.png';
    final fallbackIcon = isNonSmoking ? Icons.smoke_free : Icons.smoking_rooms;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 제목 및 구역 타입 뱃지
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    iconAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      fallbackIcon,
                      color: themeColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  area.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isNonSmoking ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isNonSmoking ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D),
                  ),
                ),
                child: Text(
                  isNonSmoking ? '🚫 금연구역' : '🚬 흡연구역',
                  style: TextStyle(
                    color: isNonSmoking ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 금연구역 경고 박스 (금연구역일 경우에만 표시)
          if (isNonSmoking)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '이 구역은 지정 금연구역입니다. 흡연 시 과태료(최대 10만원)가 부과될 수 있습니다.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF9F1239),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 1. 도로명 주소 카드
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '도로명',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    roadAddr,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: area.hasRoadAddress ? const Color(0xFF1E293B) : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (area.hasRoadAddress)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Color(0xFF64748B)),
                    tooltip: '도로명주소 복사',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _copyToClipboard(context, area.roadAddress, '도로명주소'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. 지번 주소 카드
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '지번',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lotAddr,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: area.hasLotAddress ? const Color(0xFF1E293B) : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (area.hasLotAddress)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Color(0xFF64748B)),
                    tooltip: '지번주소 복사',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _copyToClipboard(context, area.lotAddress, '지번주소'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 거리 & 면적 & 유효 반경 & 기준일자
          Row(
            children: [
              Icon(Icons.straighten, size: 17, color: Colors.grey[600]),
              const SizedBox(width: 6),
              if (distanceInMeters != null)
                Text(
                  '${distanceInMeters!.toInt()}m 거리',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '• 유효 반경 ${area.radius.toInt()}m',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              if (area.areaAr > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '(${area.areaAr.toInt()}㎡)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              const Spacer(),
              if (area.refDate.isNotEmpty)
                Text(
                  '기준일: ${area.refDate}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
