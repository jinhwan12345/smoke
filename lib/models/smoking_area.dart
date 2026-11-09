import 'dart:math' as math;

class SmokingArea {
  final String id;
  final String name;          // area_nm (구역명)
  final double areaAr;        // area_ar (면적 ㎡)
  final double latitude;      // latitude (위도)
  final double longitude;     // longitude (경도)
  final String lotAddress;    // lnmadr (지번주소)
  final String roadAddress;   // rdnmadr (도로명주소)
  final String refDate;       // ref_date (데이터 기준일자)
  final double radius;        // 면적 기반 유효 반경(m)
  final bool isNonSmoking;    // 금연구역 여부 (true: 금연구역, false: 흡연구역)

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
    this.isNonSmoking = false,
  });

  bool get hasRoadAddress => roadAddress.trim().isNotEmpty;
  bool get hasLotAddress => lotAddress.trim().isNotEmpty;

  factory SmokingArea.fromJson(Map<String, dynamic> json, {bool isNonSmoking = false}) {
    final defaultName = isNonSmoking ? '지정 금연구역' : '지정 흡연구역';
    final name = json['area_nm']?.toString() ??
        json['area_desc']?.toString() ??
        json['name']?.toString() ??
        defaultName;
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

    final bool nonSmokingFlag = isNonSmoking ||
        (json['is_non_smoking'] == true) ||
        (json['type'] == 'non_smoking');

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
      isNonSmoking: nonSmokingFlag,
    );
  }
}
