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

  static const Map<String, String> _countHeaders = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey',
    'Prefer': 'count=exact',
  };

  // 지역(시·군·구)별 흡연/금연구역 개수 메모리 캐시 (중복 요청 방지)
  final Map<String, RegionCounts> _regionCountsCache = {};
  final Set<String> _loadingRegionCodes = {};

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

  // 4. 특정 테이블의 영역 내 정확한 개수 조회 (HEAD + Prefer: count=exact)
  Future<int> _countAreasInBounds({
    required String table,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/$table?select=id&'
        'latitude=gte.$minLat&latitude=lte.$maxLat&'
        'longitude=gte.$minLng&longitude=lte.$maxLng&'
        'limit=1',
      );

      final response = await http
          .head(uri, headers: _countHeaders)
          .timeout(const Duration(seconds: 5));

      final contentRange = response.headers['content-range'];
      if (contentRange != null && contentRange.contains('/')) {
        final totalStr = contentRange.split('/').last;
        return int.tryParse(totalStr) ?? 0;
      }
    } catch (e) {
      debugPrint('Supabase $table 개수 조회 에러: $e');
    }
    return 0;
  }

  // 5. 단일 시·군·구 지역의 흡연/금연구역 개수 조회 및 캐싱
  Future<RegionCounts?> fetchRegionCounts(DistrictRegion region) async {
    if (_regionCountsCache.containsKey(region.code)) {
      return _regionCountsCache[region.code];
    }
    if (_loadingRegionCodes.contains(region.code)) {
      return null;
    }

    _loadingRegionCodes.add(region.code);
    try {
      final counts = await Future.wait([
        _countAreasInBounds(
          table: 'smoking_areas',
          minLat: region.minLat,
          maxLat: region.maxLat,
          minLng: region.minLng,
          maxLng: region.maxLng,
        ),
        _countAreasInBounds(
          table: 'non_smoking_areas',
          minLat: region.minLat,
          maxLat: region.maxLat,
          minLng: region.minLng,
          maxLng: region.maxLng,
        ),
      ]);

      final result = RegionCounts(
        region: region,
        smokingCount: counts[0],
        nonSmokingCount: counts[1],
      );
      _regionCountsCache[region.code] = result;
      return result;
    } finally {
      _loadingRegionCodes.remove(region.code);
    }
  }
}
