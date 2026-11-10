class DistrictRegion {
  final String code;
  final String name;      // 짧은 표시명 (예: '강남구', '수원시', '가평군')
  final String fullName;  // 전체 행정구역명 (예: '서울 강남구', '경기 수원시')
  final double latitude;
  final double longitude;
  final double radiusLat; // 위도 반경 (약 BBox 크기)
  final double radiusLng; // 경도 반경 (약 BBox 크기)

  const DistrictRegion({
    required this.code,
    required this.name,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    this.radiusLat = 0.045,
    this.radiusLng = 0.055,
  });

  double get minLat => latitude - radiusLat;
  double get maxLat => latitude + radiusLat;
  double get minLng => longitude - radiusLng;
  double get maxLng => longitude + radiusLng;

  String get sidoKey {
    if (code == 'sejong') return '세종';
    final parts = fullName.split(' ');
    return parts.first;
  }

  String get sigunguName {
    if (code == 'sejong') return '세종시';
    final parts = fullName.split(' ');
    return parts.length > 1 ? parts[1] : parts.first;
  }
}

class ProvinceRegion {
  final String sidoKey;    // 시·도 구분 키 (예: '서울', '경기', '부산')
  final String name;       // 배지 표시명 (예: '서울', '경기', '부산')
  final String fullName;   // 전체 행정구역명 (예: '서울특별시', '경기도')
  final double latitude;
  final double longitude;
  final double targetZoom; // 배지 탭 시 이동할 줌 레벨

  const ProvinceRegion({
    required this.sidoKey,
    required this.name,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    this.targetZoom = 11.5,
  });
}

class RegionCounts {
  final DistrictRegion region;
  final int smokingCount;
  final int nonSmokingCount;

  const RegionCounts({
    required this.region,
    required this.smokingCount,
    required this.nonSmokingCount,
  });

  int get totalCount => smokingCount + nonSmokingCount;
}

/// 전국 17개 광역시·도 대표 좌표 목록 (축소 시 광역 클러스터 배지 표시용)
const List<ProvinceRegion> kKoreaProvinces = [
  ProvinceRegion(sidoKey: '서울', name: '서울', fullName: '서울특별시', latitude: 37.5665, longitude: 126.9780, targetZoom: 12.0),
  ProvinceRegion(sidoKey: '인천', name: '인천', fullName: '인천광역시', latitude: 37.4563, longitude: 126.6322, targetZoom: 11.8),
  ProvinceRegion(sidoKey: '경기', name: '경기', fullName: '경기도', latitude: 37.2750, longitude: 127.2000, targetZoom: 11.2),
  ProvinceRegion(sidoKey: '강원', name: '강원', fullName: '강원특별자치도', latitude: 37.7500, longitude: 128.3000, targetZoom: 11.0),
  ProvinceRegion(sidoKey: '충북', name: '충북', fullName: '충청북도', latitude: 36.8000, longitude: 127.7000, targetZoom: 11.2),
  ProvinceRegion(sidoKey: '충남', name: '충남', fullName: '충청남도', latitude: 36.5500, longitude: 126.7500, targetZoom: 11.2),
  ProvinceRegion(sidoKey: '세종', name: '세종', fullName: '세종특별자치시', latitude: 36.5200, longitude: 127.2500, targetZoom: 12.2),
  ProvinceRegion(sidoKey: '대전', name: '대전', fullName: '대전광역시', latitude: 36.3200, longitude: 127.4000, targetZoom: 12.2),
  ProvinceRegion(sidoKey: '전북', name: '전북', fullName: '전북특별자치도', latitude: 35.7500, longitude: 127.1500, targetZoom: 11.2),
  ProvinceRegion(sidoKey: '광주', name: '광주', fullName: '광주광역시', latitude: 35.1600, longitude: 126.8500, targetZoom: 12.2),
  ProvinceRegion(sidoKey: '전남', name: '전남', fullName: '전라남도', latitude: 34.8000, longitude: 126.9500, targetZoom: 11.0),
  ProvinceRegion(sidoKey: '경북', name: '경북', fullName: '경상북도', latitude: 36.4500, longitude: 128.7500, targetZoom: 11.0),
  ProvinceRegion(sidoKey: '대구', name: '대구', fullName: '대구광역시', latitude: 35.8700, longitude: 128.5900, targetZoom: 12.0),
  ProvinceRegion(sidoKey: '울산', name: '울산', fullName: '울산광역시', latitude: 35.5500, longitude: 129.3100, targetZoom: 12.0),
  ProvinceRegion(sidoKey: '경남', name: '경남', fullName: '경상남도', latitude: 35.3000, longitude: 128.2500, targetZoom: 11.2),
  ProvinceRegion(sidoKey: '부산', name: '부산', fullName: '부산광역시', latitude: 35.1600, longitude: 129.0500, targetZoom: 12.0),
  ProvinceRegion(sidoKey: '제주', name: '제주', fullName: '제주특별자치도', latitude: 33.3800, longitude: 126.5500, targetZoom: 11.2),
];

final Map<String, DistrictRegion> kDistrictByCode = {
  for (final d in kKoreaDistricts) d.code: d,
};

/// 주소(도로명주소/지번주소 중 하나만 있어도 무방)와 좌표를 기반으로 229개 시·군·구 코드(code)를 판별합니다.
String? resolveDistrictCodeFromAddress({
  required String roadAddress,
  required String lotAddress,
  double? latitude,
  double? longitude,
}) {
  // 도로명주소와 지번주소 중 존재하는 주소들을 순서대로 검사 (한 가지만 있어도 정상 동작)
  final addresses = <String>[
    if (roadAddress.trim().isNotEmpty) roadAddress.trim(),
    if (lotAddress.trim().isNotEmpty) lotAddress.trim(),
  ];

  for (final rawAddr in addresses) {
    final tokens = rawAddr.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final w1 = tokens.isNotEmpty ? tokens[0] : '';
    final w2 = tokens.length > 1 ? tokens[1] : '';

    if (w1.startsWith('세종') || w2.startsWith('세종')) {
      return 'sejong';
    }
    if (w1.startsWith('인천') && w2 == '남구') {
      return 'incheon_michuhol';
    }
    if (w1 == '군위군' || w2 == '군위군') {
      return 'daegu_gunwi';
    }

    const muanTowns = {'무안읍', '삼향읍', '일로읍', '청계면', '해제면', '몽탄면', '현경면', '망운면', '운남면'};
    if (muanTowns.contains(w1)) {
      return 'jn_muan';
    }

    const haenamTowns = {
      '해남읍', '옥천면', '산이면', '송지면', '문내면', '화원면',
      '계곡면', '삼산면', '화산면', '현산면', '북평면', '북일면',
    };
    if (haenamTowns.contains(w1) && (latitude == null || latitude < 35.0)) {
      return 'jn_haenam';
    }

    List<DistrictRegion> candidates = kKoreaDistricts.where((d) => d.sigunguName == w2).toList();
    if (candidates.isEmpty && w1.isNotEmpty) {
      candidates = kKoreaDistricts.where((d) => d.sigunguName == w1).toList();
    }

    if (candidates.length == 1) {
      return candidates.first.code;
    }

    if (candidates.length > 1) {
      final isJeonnamGwangju = w1.contains('전남') ||
          w1.startsWith('전라남도') ||
          w1.contains('광주');

      for (final d in candidates) {
        final sido = d.sidoKey;
        if (w1.startsWith(sido) ||
            ((sido == '광주' || sido == '전남') && isJeonnamGwangju) ||
            (sido == '경북' && w1.startsWith('경상북도')) ||
            (sido == '경남' && w1.startsWith('경상남도')) ||
            (sido == '충북' && w1.startsWith('충청북도')) ||
            (sido == '충남' && w1.startsWith('충청남도')) ||
            (sido == '전북' && (w1.startsWith('전라북도') || w1.startsWith('전북')))) {
          return d.code;
        }
      }

      if (latitude != null && longitude != null) {
        candidates.sort((a, b) {
          final distA = (a.latitude - latitude) * (a.latitude - latitude) +
              (a.longitude - longitude) * (a.longitude - longitude);
          final distB = (b.latitude - latitude) * (b.latitude - latitude) +
              (b.longitude - longitude) * (b.longitude - longitude);
          return distA.compareTo(distB);
        });
      }
      return candidates.first.code;
    }
  }

  if (latitude != null && longitude != null) {
    DistrictRegion? nearest;
    double minDist = double.infinity;
    for (final d in kKoreaDistricts) {
      final dist = (d.latitude - latitude) * (d.latitude - latitude) +
          (d.longitude - longitude) * (d.longitude - longitude);
      if (dist < minDist) {
        minDist = dist;
        nearest = d;
      }
    }
    return nearest?.code;
  }

  return null;
}

/// 전국 시·군·구 대표 좌표 및 영역 목록
/// (서울/광역시: 구·군 단위, 도: 시·군 단위)
const List<DistrictRegion> kKoreaDistricts = [
  // ================= 서울특별시 (25개 구) =================
  DistrictRegion(code: 'seoul_jongno', name: '종로구', fullName: '서울 종로구', latitude: 37.5730, longitude: 126.9794, radiusLat: 0.030, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_jung', name: '중구', fullName: '서울 중구', latitude: 37.5641, longitude: 126.9979, radiusLat: 0.022, radiusLng: 0.030),
  DistrictRegion(code: 'seoul_yongsan', name: '용산구', fullName: '서울 용산구', latitude: 37.5326, longitude: 126.9900, radiusLat: 0.028, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_seongdong', name: '성동구', fullName: '서울 성동구', latitude: 37.5633, longitude: 127.0371, radiusLat: 0.025, radiusLng: 0.032),
  DistrictRegion(code: 'seoul_gwangjin', name: '광진구', fullName: '서울 광진구', latitude: 37.5385, longitude: 127.0823, radiusLat: 0.026, radiusLng: 0.032),
  DistrictRegion(code: 'seoul_dongdaemun', name: '동대문구', fullName: '서울 동대문구', latitude: 37.5744, longitude: 127.0400, radiusLat: 0.025, radiusLng: 0.030),
  DistrictRegion(code: 'seoul_jungnang', name: '중랑구', fullName: '서울 중랑구', latitude: 37.6066, longitude: 127.0927, radiusLat: 0.028, radiusLng: 0.032),
  DistrictRegion(code: 'seoul_seongbuk', name: '성북구', fullName: '서울 성북구', latitude: 37.5891, longitude: 127.0182, radiusLat: 0.028, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_gangbuk', name: '강북구', fullName: '서울 강북구', latitude: 37.6396, longitude: 127.0257, radiusLat: 0.030, radiusLng: 0.032),
  DistrictRegion(code: 'seoul_dobong', name: '도봉구', fullName: '서울 도봉구', latitude: 37.6688, longitude: 127.0471, radiusLat: 0.028, radiusLng: 0.030),
  DistrictRegion(code: 'seoul_nowon', name: '노원구', fullName: '서울 노원구', latitude: 37.6542, longitude: 127.0568, radiusLat: 0.032, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_eunpyeong', name: '은평구', fullName: '서울 은평구', latitude: 37.6027, longitude: 126.9291, radiusLat: 0.032, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_seodaemun', name: '서대문구', fullName: '서울 서대문구', latitude: 37.5791, longitude: 126.9368, radiusLat: 0.026, radiusLng: 0.032),
  DistrictRegion(code: 'seoul_mapo', name: '마포구', fullName: '서울 마포구', latitude: 37.5663, longitude: 126.9016, radiusLat: 0.028, radiusLng: 0.038),
  DistrictRegion(code: 'seoul_yangcheon', name: '양천구', fullName: '서울 양천구', latitude: 37.5170, longitude: 126.8665, radiusLat: 0.025, radiusLng: 0.032),
  DistrictRegion(code: 'seoul_gangseo', name: '강서구', fullName: '서울 강서구', latitude: 37.5509, longitude: 126.8495, radiusLat: 0.035, radiusLng: 0.045),
  DistrictRegion(code: 'seoul_guro', name: '구로구', fullName: '서울 구로구', latitude: 37.4954, longitude: 126.8874, radiusLat: 0.025, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_geumcheon', name: '금천구', fullName: '서울 금천구', latitude: 37.4569, longitude: 126.8954, radiusLat: 0.025, radiusLng: 0.030),
  DistrictRegion(code: 'seoul_yeongdeungpo', name: '영등포구', fullName: '서울 영등포구', latitude: 37.5264, longitude: 126.8962, radiusLat: 0.028, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_dongjak', name: '동작구', fullName: '서울 동작구', latitude: 37.5124, longitude: 126.9393, radiusLat: 0.025, radiusLng: 0.032),
  DistrictRegion(code: 'seoul_gwanak', name: '관악구', fullName: '서울 관악구', latitude: 37.4784, longitude: 126.9516, radiusLat: 0.028, radiusLng: 0.035),
  DistrictRegion(code: 'seoul_seocho', name: '서초구', fullName: '서울 서초구', latitude: 37.4837, longitude: 127.0324, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'seoul_gangnam', name: '강남구', fullName: '서울 강남구', latitude: 37.5172, longitude: 127.0473, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'seoul_songpa', name: '송파구', fullName: '서울 송파구', latitude: 37.5145, longitude: 127.1066, radiusLat: 0.032, radiusLng: 0.038),
  DistrictRegion(code: 'seoul_gangdong', name: '강동구', fullName: '서울 강동구', latitude: 37.5301, longitude: 127.1238, radiusLat: 0.028, radiusLng: 0.035),

  // ================= 인천광역시 (10개 구·군) =================
  DistrictRegion(code: 'incheon_jung', name: '인천 중구', fullName: '인천 중구', latitude: 37.4738, longitude: 126.6215, radiusLat: 0.045, radiusLng: 0.055),
  DistrictRegion(code: 'incheon_dong', name: '인천 동구', fullName: '인천 동구', latitude: 37.4739, longitude: 126.6432, radiusLat: 0.022, radiusLng: 0.025),
  DistrictRegion(code: 'incheon_michuhol', name: '미추홀구', fullName: '인천 미추홀구', latitude: 37.4635, longitude: 126.6505, radiusLat: 0.028, radiusLng: 0.032),
  DistrictRegion(code: 'incheon_yeonsu', name: '연수구', fullName: '인천 연수구', latitude: 37.4102, longitude: 126.6788, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'incheon_namdong', name: '남동구', fullName: '인천 남동구', latitude: 37.4473, longitude: 126.7314, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'incheon_bupyeong', name: '부평구', fullName: '인천 부평구', latitude: 37.5070, longitude: 126.7218, radiusLat: 0.030, radiusLng: 0.035),
  DistrictRegion(code: 'incheon_gyeyang', name: '계양구', fullName: '인천 계양구', latitude: 37.5374, longitude: 126.7377, radiusLat: 0.032, radiusLng: 0.038),
  DistrictRegion(code: 'incheon_seo', name: '인천 서구', fullName: '인천 서구', latitude: 37.5454, longitude: 126.6759, radiusLat: 0.045, radiusLng: 0.050),
  DistrictRegion(code: 'incheon_ganghwa', name: '강화군', fullName: '인천 강화군', latitude: 37.7465, longitude: 126.4881, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'incheon_ongjin', name: '옹진군', fullName: '인천 옹진군', latitude: 37.2500, longitude: 126.1500, radiusLat: 0.090, radiusLng: 0.100),

  // ================= 경기도 (31개 시·군) =================
  DistrictRegion(code: 'gg_suwon', name: '수원시', fullName: '경기 수원시', latitude: 37.2636, longitude: 127.0286, radiusLat: 0.050, radiusLng: 0.060),
  DistrictRegion(code: 'gg_seongnam', name: '성남시', fullName: '경기 성남시', latitude: 37.4200, longitude: 127.1265, radiusLat: 0.050, radiusLng: 0.060),
  DistrictRegion(code: 'gg_goyang', name: '고양시', fullName: '경기 고양시', latitude: 37.6584, longitude: 126.8320, radiusLat: 0.060, radiusLng: 0.070),
  DistrictRegion(code: 'gg_yongin', name: '용인시', fullName: '경기 용인시', latitude: 37.2411, longitude: 127.1776, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gg_bucheon', name: '부천시', fullName: '경기 부천시', latitude: 37.5034, longitude: 126.7660, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'gg_ansan', name: '안산시', fullName: '경기 안산시', latitude: 37.3219, longitude: 126.8309, radiusLat: 0.050, radiusLng: 0.060),
  DistrictRegion(code: 'gg_anyang', name: '안양시', fullName: '경기 안양시', latitude: 37.3943, longitude: 126.9568, radiusLat: 0.035, radiusLng: 0.045),
  DistrictRegion(code: 'gg_namyangju', name: '남양주시', fullName: '경기 남양주시', latitude: 37.6360, longitude: 127.2165, radiusLat: 0.070, radiusLng: 0.080),
  DistrictRegion(code: 'gg_hwaseong', name: '화성시', fullName: '경기 화성시', latitude: 37.1995, longitude: 126.8313, radiusLat: 0.085, radiusLng: 0.100),
  DistrictRegion(code: 'gg_pyeongtaek', name: '평택시', fullName: '경기 평택시', latitude: 36.9921, longitude: 127.1129, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gg_uijeongbu', name: '의정부시', fullName: '경기 의정부시', latitude: 37.7381, longitude: 127.0337, radiusLat: 0.045, radiusLng: 0.050),
  DistrictRegion(code: 'gg_siheung', name: '시흥시', fullName: '경기 시흥시', latitude: 37.3800, longitude: 126.8029, radiusLat: 0.050, radiusLng: 0.055),
  DistrictRegion(code: 'gg_paju', name: '파주시', fullName: '경기 파주시', latitude: 37.7599, longitude: 126.7802, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gg_gimpo', name: '김포시', fullName: '경기 김포시', latitude: 37.6152, longitude: 126.7156, radiusLat: 0.065, radiusLng: 0.075),
  DistrictRegion(code: 'gg_gwangmyeong', name: '광명시', fullName: '경기 광명시', latitude: 37.4786, longitude: 126.8646, radiusLat: 0.032, radiusLng: 0.035),
  DistrictRegion(code: 'gg_gwangju', name: '광주시', fullName: '경기 광주시', latitude: 37.4294, longitude: 127.2551, radiusLat: 0.070, radiusLng: 0.080),
  DistrictRegion(code: 'gg_gunpo', name: '군포시', fullName: '경기 군포시', latitude: 37.3617, longitude: 126.9352, radiusLat: 0.030, radiusLng: 0.035),
  DistrictRegion(code: 'gg_hanam', name: '하남시', fullName: '경기 하남시', latitude: 37.5393, longitude: 127.2149, radiusLat: 0.040, radiusLng: 0.045),
  DistrictRegion(code: 'gg_osan', name: '오산시', fullName: '경기 오산시', latitude: 37.1499, longitude: 127.0772, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'gg_icheon', name: '이천시', fullName: '경기 이천시', latitude: 37.2720, longitude: 127.4350, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gg_anseong', name: '안성시', fullName: '경기 안성시', latitude: 37.0080, longitude: 127.2797, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gg_uiwang', name: '의왕시', fullName: '경기 의왕시', latitude: 37.3448, longitude: 126.9683, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'gg_yangju', name: '양주시', fullName: '경기 양주시', latitude: 37.7853, longitude: 127.0458, radiusLat: 0.065, radiusLng: 0.075),
  DistrictRegion(code: 'gg_yeoju', name: '여주시', fullName: '경기 여주시', latitude: 37.2983, longitude: 127.6374, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gg_yangpyeong', name: '양평군', fullName: '경기 양평군', latitude: 37.4912, longitude: 127.4876, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gg_gwacheon', name: '과천시', fullName: '경기 과천시', latitude: 37.4292, longitude: 126.9876, radiusLat: 0.030, radiusLng: 0.035),
  DistrictRegion(code: 'gg_guri', name: '구리시', fullName: '경기 구리시', latitude: 37.5943, longitude: 127.1296, radiusLat: 0.030, radiusLng: 0.035),
  DistrictRegion(code: 'gg_pocheon', name: '포천시', fullName: '경기 포천시', latitude: 37.8949, longitude: 127.2003, radiusLat: 0.090, radiusLng: 0.100),
  DistrictRegion(code: 'gg_dongducheon', name: '동두천시', fullName: '경기 동두천시', latitude: 37.9035, longitude: 127.0605, radiusLat: 0.045, radiusLng: 0.050),
  DistrictRegion(code: 'gg_gapyeong', name: '가평군', fullName: '경기 가평군', latitude: 37.8315, longitude: 127.5096, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gg_yeoncheon', name: '연천군', fullName: '경기 연천군', latitude: 38.0966, longitude: 127.0750, radiusLat: 0.085, radiusLng: 0.095),

  // ================= 부산광역시 (16개 구·군) =================
  DistrictRegion(code: 'busan_jung', name: '부산 중구', fullName: '부산 중구', latitude: 35.1062, longitude: 129.0323, radiusLat: 0.020, radiusLng: 0.025),
  DistrictRegion(code: 'busan_seo', name: '부산 서구', fullName: '부산 서구', latitude: 35.0979, longitude: 129.0243, radiusLat: 0.028, radiusLng: 0.030),
  DistrictRegion(code: 'busan_dong', name: '부산 동구', fullName: '부산 동구', latitude: 35.1293, longitude: 129.0455, radiusLat: 0.025, radiusLng: 0.028),
  DistrictRegion(code: 'busan_yeongdo', name: '영도구', fullName: '부산 영도구', latitude: 35.0912, longitude: 129.0679, radiusLat: 0.028, radiusLng: 0.032),
  DistrictRegion(code: 'busan_busanjin', name: '부산진구', fullName: '부산 부산진구', latitude: 35.1631, longitude: 129.0532, radiusLat: 0.030, radiusLng: 0.035),
  DistrictRegion(code: 'busan_dongnae', name: '동래구', fullName: '부산 동래구', latitude: 35.2048, longitude: 129.0837, radiusLat: 0.028, radiusLng: 0.032),
  DistrictRegion(code: 'busan_nam', name: '부산 남구', fullName: '부산 남구', latitude: 35.1366, longitude: 129.0844, radiusLat: 0.030, radiusLng: 0.035),
  DistrictRegion(code: 'busan_buk', name: '부산 북구', fullName: '부산 북구', latitude: 35.1972, longitude: 128.9904, radiusLat: 0.035, radiusLng: 0.038),
  DistrictRegion(code: 'busan_haeundae', name: '해운대구', fullName: '부산 해운대구', latitude: 35.1631, longitude: 129.1636, radiusLat: 0.038, radiusLng: 0.045),
  DistrictRegion(code: 'busan_saha', name: '사하구', fullName: '부산 사하구', latitude: 35.1045, longitude: 128.9749, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'busan_geumjeong', name: '금정구', fullName: '부산 금정구', latitude: 35.2429, longitude: 129.0926, radiusLat: 0.038, radiusLng: 0.042),
  DistrictRegion(code: 'busan_gangseo', name: '부산 강서구', fullName: '부산 강서구', latitude: 35.2122, longitude: 128.9806, radiusLat: 0.055, radiusLng: 0.060),
  DistrictRegion(code: 'busan_yeonje', name: '연제구', fullName: '부산 연제구', latitude: 35.1762, longitude: 129.0797, radiusLat: 0.025, radiusLng: 0.028),
  DistrictRegion(code: 'busan_suyeong', name: '수영구', fullName: '부산 수영구', latitude: 35.1456, longitude: 129.1132, radiusLat: 0.025, radiusLng: 0.028),
  DistrictRegion(code: 'busan_sasang', name: '사상구', fullName: '부산 사상구', latitude: 35.1526, longitude: 128.9912, radiusLat: 0.032, radiusLng: 0.035),
  DistrictRegion(code: 'busan_gijang', name: '기장군', fullName: '부산 기장군', latitude: 35.2446, longitude: 129.2223, radiusLat: 0.065, radiusLng: 0.070),

  // ================= 대구광역시 (9개 구·군) =================
  DistrictRegion(code: 'daegu_jung', name: '대구 중구', fullName: '대구 중구', latitude: 35.8693, longitude: 128.6062, radiusLat: 0.022, radiusLng: 0.025),
  DistrictRegion(code: 'daegu_dong', name: '대구 동구', fullName: '대구 동구', latitude: 35.8868, longitude: 128.6356, radiusLat: 0.050, radiusLng: 0.060),
  DistrictRegion(code: 'daegu_seo', name: '대구 서구', fullName: '대구 서구', latitude: 35.8718, longitude: 128.5592, radiusLat: 0.028, radiusLng: 0.032),
  DistrictRegion(code: 'daegu_nam', name: '대구 남구', fullName: '대구 남구', latitude: 35.8460, longitude: 128.5977, radiusLat: 0.025, radiusLng: 0.028),
  DistrictRegion(code: 'daegu_buk', name: '대구 북구', fullName: '대구 북구', latitude: 35.8857, longitude: 128.5829, radiusLat: 0.045, radiusLng: 0.050),
  DistrictRegion(code: 'daegu_suseong', name: '수성구', fullName: '대구 수성구', latitude: 35.8582, longitude: 128.6306, radiusLat: 0.040, radiusLng: 0.048),
  DistrictRegion(code: 'daegu_dalseo', name: '달서구', fullName: '대구 달서구', latitude: 35.8299, longitude: 128.5327, radiusLat: 0.040, radiusLng: 0.045),
  DistrictRegion(code: 'daegu_dalseong', name: '달성군', fullName: '대구 달성군', latitude: 35.7747, longitude: 128.4314, radiusLat: 0.070, radiusLng: 0.080),
  DistrictRegion(code: 'daegu_gunwi', name: '군위군', fullName: '대구 군위군', latitude: 36.2429, longitude: 128.5728, radiusLat: 0.080, radiusLng: 0.090),

  // ================= 대전광역시 (5개 구) =================
  DistrictRegion(code: 'daejeon_dong', name: '대전 동구', fullName: '대전 동구', latitude: 36.3120, longitude: 127.4549, radiusLat: 0.045, radiusLng: 0.050),
  DistrictRegion(code: 'daejeon_jung', name: '대전 중구', fullName: '대전 중구', latitude: 36.3256, longitude: 127.4214, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'daejeon_seo', name: '대전 서구', fullName: '대전 서구', latitude: 36.3555, longitude: 127.3838, radiusLat: 0.040, radiusLng: 0.045),
  DistrictRegion(code: 'daejeon_yuseong', name: '유성구', fullName: '대전 유성구', latitude: 36.3622, longitude: 127.3561, radiusLat: 0.050, radiusLng: 0.055),
  DistrictRegion(code: 'daejeon_daedeok', name: '대덕구', fullName: '대전 대덕구', latitude: 36.3467, longitude: 127.4157, radiusLat: 0.040, radiusLng: 0.045),

  // ================= 광주광역시 (5개 구) =================
  DistrictRegion(code: 'gwangju_dong', name: '광주 동구', fullName: '광주 동구', latitude: 35.1460, longitude: 126.9231, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'gwangju_seo', name: '광주 서구', fullName: '광주 서구', latitude: 35.1520, longitude: 126.8895, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'gwangju_nam', name: '광주 남구', fullName: '광주 남구', latitude: 35.1329, longitude: 126.9025, radiusLat: 0.038, radiusLng: 0.042),
  DistrictRegion(code: 'gwangju_buk', name: '광주 북구', fullName: '광주 북구', latitude: 35.1741, longitude: 126.9120, radiusLat: 0.045, radiusLng: 0.050),
  DistrictRegion(code: 'gwangju_gwangsan', name: '광산구', fullName: '광주 광산구', latitude: 35.1396, longitude: 126.7937, radiusLat: 0.055, radiusLng: 0.065),

  // ================= 울산광역시 (5개 구·군) =================
  DistrictRegion(code: 'ulsan_jung', name: '울산 중구', fullName: '울산 중구', latitude: 35.5694, longitude: 129.3328, radiusLat: 0.032, radiusLng: 0.038),
  DistrictRegion(code: 'ulsan_nam', name: '울산 남구', fullName: '울산 남구', latitude: 35.5438, longitude: 129.3301, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'ulsan_dong', name: '울산 동구', fullName: '울산 동구', latitude: 35.5050, longitude: 129.4166, radiusLat: 0.035, radiusLng: 0.040),
  DistrictRegion(code: 'ulsan_buk', name: '울산 북구', fullName: '울산 북구', latitude: 35.5826, longitude: 129.3612, radiusLat: 0.048, radiusLng: 0.055),
  DistrictRegion(code: 'ulsan_ulju', name: '울주군', fullName: '울산 울주군', latitude: 35.5222, longitude: 129.2424, radiusLat: 0.085, radiusLng: 0.095),

  // ================= 세종특별자치시 =================
  DistrictRegion(code: 'sejong', name: '세종시', fullName: '세종특별자치시', latitude: 36.4800, longitude: 127.2890, radiusLat: 0.075, radiusLng: 0.085),

  // ================= 강원특별자치도 (18개 시·군) =================
  DistrictRegion(code: 'gw_chuncheon', name: '춘천시', fullName: '강원 춘천시', latitude: 37.8813, longitude: 127.7298, radiusLat: 0.090, radiusLng: 0.100),
  DistrictRegion(code: 'gw_wonju', name: '원주시', fullName: '강원 원주시', latitude: 37.3422, longitude: 127.9202, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gw_gangneung', name: '강릉시', fullName: '강원 강릉시', latitude: 37.7519, longitude: 128.8761, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gw_donghae', name: '동해시', fullName: '강원 동해시', latitude: 37.5247, longitude: 129.1143, radiusLat: 0.060, radiusLng: 0.070),
  DistrictRegion(code: 'gw_taebaek', name: '태백시', fullName: '강원 태백시', latitude: 37.1641, longitude: 128.9856, radiusLat: 0.065, radiusLng: 0.075),
  DistrictRegion(code: 'gw_sokcho', name: '속초시', fullName: '강원 속초시', latitude: 38.2070, longitude: 128.5918, radiusLat: 0.050, radiusLng: 0.060),
  DistrictRegion(code: 'gw_samcheok', name: '삼척시', fullName: '강원 삼척시', latitude: 37.4499, longitude: 129.1652, radiusLat: 0.090, radiusLng: 0.100),
  DistrictRegion(code: 'gw_hongcheon', name: '홍천군', fullName: '강원 홍천군', latitude: 37.6970, longitude: 127.8887, radiusLat: 0.100, radiusLng: 0.110),
  DistrictRegion(code: 'gw_hoengseong', name: '횡성군', fullName: '강원 횡성군', latitude: 37.4918, longitude: 127.9850, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gw_yeongwol', name: '영월군', fullName: '강원 영월군', latitude: 37.1836, longitude: 128.4618, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gw_pyeongchang', name: '평창군', fullName: '강원 평창군', latitude: 37.3708, longitude: 128.3902, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gw_jeongseon', name: '정선군', fullName: '강원 정선군', latitude: 37.3806, longitude: 128.6608, radiusLat: 0.090, radiusLng: 0.100),
  DistrictRegion(code: 'gw_cheorwon', name: '철원군', fullName: '강원 철원군', latitude: 38.1466, longitude: 127.3133, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gw_hwacheon', name: '화천군', fullName: '강원 화천군', latitude: 38.1062, longitude: 127.7082, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gw_yanggu', name: '양구군', fullName: '강원 양구군', latitude: 38.1099, longitude: 127.9899, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gw_inje', name: '인제군', fullName: '강원 인제군', latitude: 38.0697, longitude: 128.1703, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gw_goseong', name: '고성군', fullName: '강원 고성군', latitude: 38.3806, longitude: 128.4678, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gw_yangyang', name: '양양군', fullName: '강원 양양군', latitude: 38.0754, longitude: 128.6189, radiusLat: 0.080, radiusLng: 0.090),

  // ================= 충청북도 (11개 시·군) =================
  DistrictRegion(code: 'cb_cheongju', name: '청주시', fullName: '충북 청주시', latitude: 36.6424, longitude: 127.4890, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cb_chungju', name: '충주시', fullName: '충북 충주시', latitude: 36.9910, longitude: 127.9259, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cb_jecheon', name: '제천시', fullName: '충북 제천시', latitude: 37.1326, longitude: 128.1909, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cb_boeun', name: '보은군', fullName: '충북 보은군', latitude: 36.4894, longitude: 127.7295, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cb_okcheon', name: '옥천군', fullName: '충북 옥천군', latitude: 36.3064, longitude: 127.5714, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cb_yeongdong', name: '영동군', fullName: '충북 영동군', latitude: 36.1750, longitude: 127.7834, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cb_jeungpyeong', name: '증평군', fullName: '충북 증평군', latitude: 36.7854, longitude: 127.5815, radiusLat: 0.050, radiusLng: 0.060),
  DistrictRegion(code: 'cb_jincheon', name: '진천군', fullName: '충북 진천군', latitude: 36.8554, longitude: 127.4355, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'cb_goesan', name: '괴산군', fullName: '충북 괴산군', latitude: 36.8153, longitude: 127.7867, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cb_eumseong', name: '음성군', fullName: '충북 음성군', latitude: 36.9403, longitude: 127.6905, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cb_danyang', name: '단양군', fullName: '충북 단양군', latitude: 36.9845, longitude: 128.3655, radiusLat: 0.085, radiusLng: 0.095),

  // ================= 충청남도 (15개 시·군) =================
  DistrictRegion(code: 'cn_cheonan', name: '천안시', fullName: '충남 천안시', latitude: 36.8151, longitude: 127.1139, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cn_gongju', name: '공주시', fullName: '충남 공주시', latitude: 36.4465, longitude: 127.1190, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cn_boryeong', name: '보령시', fullName: '충남 보령시', latitude: 36.3334, longitude: 126.6129, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_asan', name: '아산시', fullName: '충남 아산시', latitude: 36.7898, longitude: 127.0018, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_seosan', name: '서산시', fullName: '충남 서산시', latitude: 36.7845, longitude: 126.4503, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cn_nonsan', name: '논산시', fullName: '충남 논산시', latitude: 36.1872, longitude: 127.0989, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_gyeryong', name: '계룡시', fullName: '충남 계룡시', latitude: 36.2745, longitude: 127.2486, radiusLat: 0.045, radiusLng: 0.055),
  DistrictRegion(code: 'cn_dangjin', name: '당진시', fullName: '충남 당진시', latitude: 36.8936, longitude: 126.6283, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cn_geumsan', name: '금산군', fullName: '충남 금산군', latitude: 36.1086, longitude: 127.4882, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_buyeo', name: '부여군', fullName: '충남 부여군', latitude: 36.2758, longitude: 126.9098, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'cn_seocheon', name: '서천군', fullName: '충남 서천군', latitude: 36.0803, longitude: 126.6914, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_cheongyang', name: '청양군', fullName: '충남 청양군', latitude: 36.4590, longitude: 126.8022, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_hongseong', name: '홍성군', fullName: '충남 홍성군', latitude: 36.6013, longitude: 126.6608, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_yesan', name: '예산군', fullName: '충남 예산군', latitude: 36.6826, longitude: 126.8484, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'cn_taean', name: '태안군', fullName: '충남 태안군', latitude: 36.7456, longitude: 126.2979, radiusLat: 0.085, radiusLng: 0.095),

  // ================= 전북특별자치도 (14개 시·군) =================
  DistrictRegion(code: 'jb_jeonju', name: '전주시', fullName: '전북 전주시', latitude: 35.8242, longitude: 127.1480, radiusLat: 0.065, radiusLng: 0.075),
  DistrictRegion(code: 'jb_gunsan', name: '군산시', fullName: '전북 군산시', latitude: 35.9677, longitude: 126.7366, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jb_iksan', name: '익산시', fullName: '전북 익산시', latitude: 35.9483, longitude: 126.9576, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jb_jeongeup', name: '정읍시', fullName: '전북 정읍시', latitude: 35.5699, longitude: 126.8560, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_namwon', name: '남원시', fullName: '전북 남원시', latitude: 35.4164, longitude: 127.3904, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_gimje', name: '김제시', fullName: '전북 김제시', latitude: 35.8036, longitude: 126.8808, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jb_wanju', name: '완주군', fullName: '전북 완주군', latitude: 35.9047, longitude: 127.1620, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_jinan', name: '진안군', fullName: '전북 진안군', latitude: 35.7918, longitude: 127.4249, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_무주', name: '무주군', fullName: '전북 무주군', latitude: 36.0068, longitude: 127.6608, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_jangsu', name: '장수군', fullName: '전북 장수군', latitude: 35.6474, longitude: 127.5215, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_imsil', name: '임실군', fullName: '전북 임실군', latitude: 35.6178, longitude: 127.2891, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_sunchang', name: '순창군', fullName: '전북 순창군', latitude: 35.3744, longitude: 127.1374, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jb_gochang', name: '고창군', fullName: '전북 고창군', latitude: 35.4358, longitude: 126.7020, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jb_buan', name: '부안군', fullName: '전북 부안군', latitude: 35.7318, longitude: 126.7330, radiusLat: 0.080, radiusLng: 0.090),

  // ================= 전라남도 (22개 시·군) =================
  DistrictRegion(code: 'jn_mokpo', name: '목포시', fullName: '전남 목포시', latitude: 34.8118, longitude: 126.3922, radiusLat: 0.050, radiusLng: 0.060),
  DistrictRegion(code: 'jn_yeosu', name: '여수시', fullName: '전남 여수시', latitude: 34.7604, longitude: 127.6622, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_suncheon', name: '순천시', fullName: '전남 순천시', latitude: 34.9506, longitude: 127.4872, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_naju', name: '나주시', fullName: '전남 나주시', latitude: 35.0158, longitude: 126.7108, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_gwangyang', name: '광양시', fullName: '전남 광양시', latitude: 34.9407, longitude: 127.6959, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_damyang', name: '담양군', fullName: '전남 담양군', latitude: 35.3211, longitude: 126.9882, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_gokseong', name: '곡성군', fullName: '전남 곡성군', latitude: 35.2820, longitude: 127.2919, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_gurye', name: '구례군', fullName: '전남 구례군', latitude: 35.2025, longitude: 127.4628, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_goheung', name: '고흥군', fullName: '전남 고흥군', latitude: 34.6112, longitude: 127.2850, radiusLat: 0.090, radiusLng: 0.100),
  DistrictRegion(code: 'jn_boseong', name: '보성군', fullName: '전남 보성군', latitude: 34.7715, longitude: 127.0800, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_hwasun', name: '화순군', fullName: '전남 화순군', latitude: 35.0645, longitude: 126.9865, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_jangheung', name: '장흥군', fullName: '전남 장흥군', latitude: 34.6817, longitude: 126.9069, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_gangjin', name: '강진군', fullName: '전남 강진군', latitude: 34.6421, longitude: 126.7672, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_haenam', name: '해남군', fullName: '전남 해남군', latitude: 34.5735, longitude: 126.5989, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'jn_yeongam', name: '영암군', fullName: '전남 영암군', latitude: 34.8002, longitude: 126.6968, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_muan', name: '무안군', fullName: '전남 무안군', latitude: 34.9904, longitude: 126.4817, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_hampyeong', name: '함평군', fullName: '전남 함평군', latitude: 35.0659, longitude: 126.5165, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_yeonggwang', name: '영광군', fullName: '전남 영광군', latitude: 35.2772, longitude: 126.5120, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_jangseong', name: '장성군', fullName: '전남 장성군', latitude: 35.3019, longitude: 126.7848, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'jn_wando', name: '완도군', fullName: '전남 완도군', latitude: 34.3110, longitude: 126.7550, radiusLat: 0.090, radiusLng: 0.100),
  DistrictRegion(code: 'jn_jindo', name: '진도군', fullName: '전남 진도군', latitude: 34.4868, longitude: 126.2635, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'jn_sinan', name: '신안군', fullName: '전남 신안군', latitude: 34.8336, longitude: 126.1086, radiusLat: 0.095, radiusLng: 0.110),

  // ================= 경상북도 (21개 시·군) =================
  DistrictRegion(code: 'gb_pohang', name: '포항시', fullName: '경북 포항시', latitude: 36.0190, longitude: 129.3435, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gb_gyeongju', name: '경주시', fullName: '경북 경주시', latitude: 35.8562, longitude: 129.2247, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gb_gimcheon', name: '김천시', fullName: '경북 김천시', latitude: 36.1398, longitude: 128.1136, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gb_andong', name: '안동시', fullName: '경북 안동시', latitude: 36.5684, longitude: 128.7294, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gb_gumi', name: '구미시', fullName: '경북 구미시', latitude: 36.1195, longitude: 128.3446, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gb_yeongju', name: '영주시', fullName: '경북 영주시', latitude: 36.8057, longitude: 128.6241, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gb_yeongcheon', name: '영천시', fullName: '경북 영천시', latitude: 35.9733, longitude: 128.9386, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gb_sangju', name: '상주시', fullName: '경북 상주시', latitude: 36.4109, longitude: 128.1591, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gb_mungyeong', name: '문경시', fullName: '경북 문경시', latitude: 36.5865, longitude: 128.1868, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gb_gyeongsan', name: '경산시', fullName: '경북 경산시', latitude: 35.8251, longitude: 128.7413, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gb_uiseong', name: '의성군', fullName: '경북 의성군', latitude: 36.3527, longitude: 128.6970, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gb_cheongsong', name: '청송군', fullName: '경북 청송군', latitude: 36.4363, longitude: 129.0571, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gb_yeongyang', name: '영양군', fullName: '경북 영양군', latitude: 36.6667, longitude: 129.1125, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gb_yeongdeok', name: '영덕군', fullName: '경북 영덕군', latitude: 36.4151, longitude: 129.3653, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gb_cheongdo', name: '청도군', fullName: '경북 청도군', latitude: 35.6473, longitude: 128.7340, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gb_goryeong', name: '고령군', fullName: '경북 고령군', latitude: 35.7261, longitude: 128.2629, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gb_seongju', name: '성주군', fullName: '경북 성주군', latitude: 35.9191, longitude: 128.2830, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gb_chilgok', name: '칠곡군', fullName: '경북 칠곡군', latitude: 35.9954, longitude: 128.4017, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gb_예천', name: '예천군', fullName: '경북 예천군', latitude: 36.6577, longitude: 128.4528, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gb_bonghwa', name: '봉화군', fullName: '경북 봉화군', latitude: 36.8931, longitude: 128.7324, radiusLat: 0.090, radiusLng: 0.100),
  DistrictRegion(code: 'gb_uljin', name: '울진군', fullName: '경북 울진군', latitude: 36.9931, longitude: 129.4004, radiusLat: 0.095, radiusLng: 0.105),
  DistrictRegion(code: 'gb_ulleung', name: '울릉군', fullName: '경북 울릉군', latitude: 37.4844, longitude: 130.9057, radiusLat: 0.070, radiusLng: 0.080),

  // ================= 경상남도 (18개 시·군) =================
  DistrictRegion(code: 'gn_changwon', name: '창원시', fullName: '경남 창원시', latitude: 35.2280, longitude: 128.6811, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gn_jinju', name: '진주시', fullName: '경남 진주시', latitude: 35.1800, longitude: 128.1076, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gn_tongyeong', name: '통영시', fullName: '경남 통영시', latitude: 34.8544, longitude: 128.4332, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gn_sacheon', name: '사천시', fullName: '경남 사천시', latitude: 35.0038, longitude: 128.0642, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gn_gimhae', name: '김해시', fullName: '경남 김해시', latitude: 35.2285, longitude: 128.8894, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gn_miryang', name: '밀양시', fullName: '경남 밀양시', latitude: 35.5038, longitude: 128.7464, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gn_geoje', name: '거제시', fullName: '경남 거제시', latitude: 34.8806, longitude: 128.6211, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gn_yangsan', name: '양산시', fullName: '경남 양산시', latitude: 35.3350, longitude: 129.0372, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gn_uiryeong', name: '의령군', fullName: '경남 의령군', latitude: 35.3222, longitude: 128.2617, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gn_haman', name: '함안군', fullName: '경남 함안군', latitude: 35.2726, longitude: 128.4065, radiusLat: 0.075, radiusLng: 0.085),
  DistrictRegion(code: 'gn_changnyeong', name: '창녕군', fullName: '경남 창녕군', latitude: 35.5446, longitude: 128.4922, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gn_goseong', name: '경남 고성군', fullName: '경남 고성군', latitude: 34.9731, longitude: 128.3222, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gn_namhae', name: '남해군', fullName: '경남 남해군', latitude: 34.8377, longitude: 127.8924, radiusLat: 0.080, radiusLng: 0.090),
  DistrictRegion(code: 'gn_hadong', name: '하동군', fullName: '경남 하동군', latitude: 35.0672, longitude: 127.7513, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gn_sancheong', name: '산청군', fullName: '경남 산청군', latitude: 35.4156, longitude: 127.8735, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gn_hamyang', name: '함양군', fullName: '경남 함양군', latitude: 35.5205, longitude: 127.7252, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gn_geochang', name: '거창군', fullName: '경남 거창군', latitude: 35.6867, longitude: 127.9095, radiusLat: 0.085, radiusLng: 0.095),
  DistrictRegion(code: 'gn_hapcheon', name: '합천군', fullName: '경남 합천군', latitude: 35.5666, longitude: 128.1658, radiusLat: 0.090, radiusLng: 0.100),

  // ================= 제주특별자치도 (2개 시) =================
  DistrictRegion(code: 'jeju_jeju', name: '제주시', fullName: '제주 제주시', latitude: 33.4996, longitude: 126.5312, radiusLat: 0.100, radiusLng: 0.150),
  DistrictRegion(code: 'jeju_seogwipo', name: '서귀포시', fullName: '제주 서귀포시', latitude: 33.2541, longitude: 126.5601, radiusLat: 0.100, radiusLng: 0.150),
];
