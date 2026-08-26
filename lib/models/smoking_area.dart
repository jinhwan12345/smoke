import 'dart:math' as math;

class SmokingArea {
  final String id;
  final String name;          // area_nm (흡연구역명)
  final double areaAr;        // area_ar (면적 ㎡)
  final double latitude;      // latitude (위도)
  final double longitude;     // longitude (경도)
  final String lotAddress;    // lnmadr (지번주소)
  final String roadAddress;   // rdnmadr (도로명주소)
  final String refDate;       // ref_date (데이터 기준일자)
  final double radius;        // 면적 기반 유효 반경(m)

  SmokingArea({
    required this.id,
    required this.name,
    required this.areaAr,
    required this.latitude,
    required this.longitude,
    required this.lotAddress,
    required this.roadAddress,
    required this.refDate,
    required this.radius,
  });

  // 대표 주소 (도로명 우선, 없으면 지번)
  String get address {
    if (roadAddress.isNotEmpty) return roadAddress;
    if (lotAddress.isNotEmpty) return lotAddress;
    return '주소 정보 없음';
  }

  bool get hasRoadAddress => roadAddress.trim().isNotEmpty;
  bool get hasLotAddress => lotAddress.trim().isNotEmpty;

  factory SmokingArea.fromJson(Map<String, dynamic> json) {
    final name = json['area_nm']?.toString() ?? json['area_desc']?.toString() ?? json['name']?.toString() ?? '지정 흡연구역';
    final lotAddr = json['lnmadr']?.toString() ?? '';
    final roadAddr = json['rdnmadr']?.toString() ?? json['address']?.toString() ?? '';
    final refDate = json['ref_date']?.toString() ?? '';

    // 면적(area_ar) 파싱
    double ar = 0.0;
    if (json['area_ar'] != null) {
      ar = (json['area_ar'] as num).toDouble();
    }

    // 면적 기반 반경 계산 (최소 8m ~ 최대 30m, 기본 20m)
    double rad = 20.0;
    if (ar > 0) {
      rad = (math.sqrt(ar / math.pi) * 2).clamp(8.0, 30.0);
    } else if (json['radius'] != null) {
      rad = (json['radius'] as num).toDouble();
    }

    return SmokingArea(
      id: json['id']?.toString() ?? '',
      name: name,
      areaAr: ar,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      lotAddress: lotAddr,
      roadAddress: roadAddr,
      refDate: refDate,
      radius: rad,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'area_nm': name,
      'area_ar': areaAr,
      'latitude': latitude,
      'longitude': longitude,
      'lnmadr': lotAddress,
      'rdnmadr': roadAddress,
      'ref_date': refDate,
    };
  }
}
