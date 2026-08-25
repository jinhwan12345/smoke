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

  @override
  Widget build(BuildContext context) {
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

          // 제목 및 태그
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: Text(
                  area.type,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 주소
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  area.address.isEmpty ? '상세 주소 정보 없음' : area.address,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: '주소 복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: area.address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('주소가 클립보드에 복사되었습니다.')),
                  );
                },
              ),
            ],
          ),

          // 거리 & 유효 반경
          Row(
            children: [
              Icon(Icons.straighten, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 6),
              if (distanceInMeters != null)
                Text(
                  '현재 위치로부터 ${distanceInMeters!.toInt()}m 거리',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
              const SizedBox(width: 12),
              Text(
                '• 유효 반경 ${area.radius.toInt()}m',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),

          if (area.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                area.description,
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
            ),
          ],

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
