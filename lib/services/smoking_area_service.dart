import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/district_region.dart';
import '../models/smoking_area.dart';

class SmokingAreaService {
  static const String supabaseUrl = 'https://cqtojdswnwgshqhnwzmg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_4nbwJnVgf34sKrCKpNsSTQ_zy8QudVU';

  static const Map<String, String> _headers = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey',
  };

  // 지역(시·군·구)별 흡연/금연구역 개수 메모리 캐시 (중복 요청 방지)
  final Map<String, RegionCounts> _regionCountsCache = {};
  Future<bool>? _loadingAllCountsFuture;

  Map<String, RegionCounts> get cachedRegionCounts => _regionCountsCache;

  // 현재 지도 화면(Bounding Box) 내 구역 동적 조회 (흡연구역 / 금연구역 공통)
  Future<List<SmokingArea>> _loadAreasInBounds({
    required String table,
    required bool isNonSmoking,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 150,
  }) async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/$table?'
        'latitude=gte.$minLat&latitude=lte.$maxLat&'
        'longitude=gte.$minLng&longitude=lte.$maxLng&'
        'limit=$limit',
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList
            .map((item) => SmokingArea.fromJson(item, isNonSmoking: isNonSmoking))
            .toList();
      }
    } catch (e) {
      debugPrint('Supabase $table 조회 에러: $e');
    }
    return [];
  }

  // 1. 현재 화면 영역(Bounding Box) 내 흡연구역 동적 조회
  Future<List<SmokingArea>> loadSmokingAreasInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 150,
  }) {
    return _loadAreasInBounds(
      table: 'smoking_areas',
      isNonSmoking: false,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: limit,
    );
  }

  // 2. 현재 화면 영역(Bounding Box) 내 금연구역 동적 조회
  Future<List<SmokingArea>> loadNonSmokingAreasInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 150,
  }) {
    return _loadAreasInBounds(
      table: 'non_smoking_areas',
      isNonSmoking: true,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: limit,
    );
  }

  // 3. 내 위치 주변(반경 ~500m) 흡연/금연구역 동시 조회 (초기 지오펜싱 및 상태 배너 판정용)
  Future<({List<SmokingArea> smoking, List<SmokingArea> nonSmoking})> loadNearbyAreas({
    required double userLat,
    required double userLng,
    double radiusDegrees = 0.005, // 약 500m
    int limit = 50,
  }) async {
    final minLat = userLat - radiusDegrees;
    final maxLat = userLat + radiusDegrees;
    final minLng = userLng - (radiusDegrees * 1.2);
    final maxLng = userLng + (radiusDegrees * 1.2);

    final results = await Future.wait([
      loadSmokingAreasInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        limit: limit,
      ),
      loadNonSmokingAreasInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        limit: limit,
      ),
    ]);

    return (smoking: results[0], nonSmoking: results[1]);
  }

  // 4. district_counts 요약 테이블에서 전국 229개 시·군·구 구역 수 일괄 조회 (1회 요청)
  Future<bool> loadAllDistrictCounts() {
    if (_regionCountsCache.length >= kKoreaDistricts.length) {
      return Future.value(true);
    }
    return _loadingAllCountsFuture ??= _fetchAllDistrictCountsInternal().whenComplete(() {
      _loadingAllCountsFuture = null;
    });
  }

  Future<bool> _fetchAllDistrictCountsInternal() async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/district_counts?'
        'select=code,smoking_count,non_smoking_count&limit=300',
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        if (jsonList.isNotEmpty) {
          for (final region in kKoreaDistricts) {
            _regionCountsCache.putIfAbsent(
              region.code,
              () => RegionCounts(region: region, smokingCount: 0, nonSmokingCount: 0),
            );
          }

          for (final item in jsonList) {
            final code = item['code']?.toString() ?? '';
            final region = kDistrictByCode[code];
            if (region != null) {
              final smokingCount = (item['smoking_count'] as num?)?.toInt() ?? 0;
              final nonSmokingCount = (item['non_smoking_count'] as num?)?.toInt() ?? 0;
              _regionCountsCache[code] = RegionCounts(
                region: region,
                smokingCount: smokingCount,
                nonSmokingCount: nonSmokingCount,
              );
            }
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('Supabase district_counts 일괄 조회 에러: $e');
    }

    // Fallback: district_counts 테이블 생성 전인 경우 smoking_areas를 주소 기준으로 집계
    return _fallbackAggregateSmokingAreasByAddress();
  }

  Future<bool> _fallbackAggregateSmokingAreasByAddress() async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/smoking_areas?'
        'select=id,lnmadr,rdnmadr,latitude,longitude&limit=5000',
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final Map<String, int> smokingByCode = {};

        for (final item in jsonList) {
          final lnmadr = item['lnmadr']?.toString() ?? '';
          final rdnmadr = item['rdnmadr']?.toString() ?? '';
          final lat = (item['latitude'] as num?)?.toDouble();
          final lng = (item['longitude'] as num?)?.toDouble();

          final code = resolveDistrictCodeFromAddress(
            roadAddress: rdnmadr,
            lotAddress: lnmadr,
            latitude: lat,
            longitude: lng,
          );
          if (code != null) {
            smokingByCode[code] = (smokingByCode[code] ?? 0) + 1;
          }
        }

        for (final region in kKoreaDistricts) {
          _regionCountsCache[region.code] = RegionCounts(
            region: region,
            smokingCount: smokingByCode[region.code] ?? 0,
            nonSmokingCount: 0,
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('Fallback 흡연구역 주소별 집계 에러: $e');
    }
    return false;
  }

  // 5. 단일 시·군·구 지역의 흡연/금연구역 개수 조회 및 캐싱
  Future<RegionCounts?> fetchRegionCounts(DistrictRegion region) async {
    if (_regionCountsCache.containsKey(region.code)) {
      return _regionCountsCache[region.code];
    }

    await loadAllDistrictCounts();
    return _regionCountsCache[region.code];
  }

  // 6. 광역시·도(sidoKey) 단위 합산 흡연/금연구역 개수 반환
  ({int smokingCount, int nonSmokingCount})? getProvinceCounts(String sidoKey) {
    if (_regionCountsCache.isEmpty) return null;

    int smoking = 0;
    int nonSmoking = 0;
    for (final entry in _regionCountsCache.values) {
      if (entry.region.sidoKey == sidoKey) {
        smoking += entry.smokingCount;
        nonSmoking += entry.nonSmokingCount;
      }
    }
    return (smokingCount: smoking, nonSmokingCount: nonSmoking);
  }
}
