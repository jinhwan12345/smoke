import 'dart:math' as math;

class SmokingArea {
  final String id;
  final String name;        // area_nm
  final String address;     // rdnmadr or lnmadr
  final double latitude;    // latitude
  final double longitude;   // longitude
  final double radius;      // area_ar (면적 기반 계산 또는 기본 20m)
  final String type;        // area_se
  final String description; // area_desc
  final String? instNm;     // inst_nm (관리기관)
  final String? fcltyKnd;   // fclty_knd

  SmokingArea({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radius = 20.0,
    this.type = '개방형',
    this.description = '',
    this.instNm,
    this.fcltyKnd,
  });

  factory SmokingArea.fromJson(Map<String, dynamic> json) {
    // 새로운 공공데이터 표준 컬럼 매핑
    final name = json['area_nm']?.toString() ?? json['name']?.toString() ?? '지정 흡연구역';
    final address = json['rdnmadr']?.toString() ?? json['lnmadr']?.toString() ?? json['address']?.toString() ?? '';
    final type = json['area_se']?.toString() ?? json['type']?.toString() ?? '흡연구역';
    final desc = json['area_desc']?.toString() ?? json['description']?.toString() ?? '';
    final inst = json['inst_nm']?.toString();
    final fclty = json['fclty_knd']?.toString();

    // 면적(area_ar)으로부터 반경 계산
    double rad = 20.0;
    if (json['area_ar'] != null) {
      double ar = (json['area_ar'] as num).toDouble();
      if (ar > 0) {
        rad = (math.sqrt(ar / math.pi) * 2).clamp(8.0, 30.0);
      }
    } else if (json['radius'] != null) {
      rad = (json['radius'] as num).toDouble();
    }

    return SmokingArea(
      id: json['id']?.toString() ?? '',
      name: name,
      address: address,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: rad,
      type: type,
      description: desc,
      instNm: inst,
      fcltyKnd: fclty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'area_nm': name,
      'rdnmadr': address,
      'latitude': latitude,
      'longitude': longitude,
      'area_se': type,
      'area_desc': description,
      'inst_nm': instNm,
      'fclty_knd': fcltyKnd,
    };
  }
}
