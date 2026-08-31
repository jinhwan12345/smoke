import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/smoking_area.dart';

class SmokingAreaService {
  List<SmokingArea> _cachedSmokingAreas = [];
  List<SmokingArea> _cachedLocalNonSmokingAreas = [];

  // Supabase 실시간 클라우드 DB 설정
  static const String supabaseUrl = 'https://cqtojdswnwgshqhnwzmg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_4nbwJnVgf34sKrCKpNsSTQ_zy8QudVU';

  // 1. 흡연구역(smoking_areas) 전체 로드 (흡연구역은 데이터 수가 적어 전체 로드 유지)
  Future<List<SmokingArea>> loadSmokingAreas() async {
    try {
      final response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/smoking_areas?select=*'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        if (jsonList.isNotEmpty) {
          _cachedSmokingAreas = jsonList
              .map((item) => SmokingArea.fromJson(item, isNonSmoking: false))
              .toList();
          return _cachedSmokingAreas;
        }
      }
    } catch (e) {
      debugPrint('Supabase 흡연구역 통신 오류 또는 타임아웃, 로컬 데이터 사용: $e');
    }

    return await loadLocalSmokingAreas();
  }

  // 2. 현재 지도 화면(Bounding Box)에 보이는 금연구역만 동적 조회 (대용량 5만건 최적화)
  Future<List<SmokingArea>> loadNonSmokingAreasInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 150,
  }) async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/non_smoking_areas?'
        'latitude=gte.$minLat&latitude=lte.$maxLat&'
        'longitude=gte.$minLng&longitude=lte.$maxLng&'
        'limit=$limit',
      );

      final response = await http.get(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList
            .map((item) => SmokingArea.fromJson(item, isNonSmoking: true))
            .toList();
      }
    } catch (e) {
      debugPrint('Supabase 화면 영역 금연구역 조회 에러: $e');
    }

    // 통신 실패 시 로컬 fallback에서 영역 필터링
    final localList = await loadLocalNonSmokingAreas();
    return localList.where((area) {
      return area.latitude >= minLat &&
          area.latitude <= maxLat &&
          area.longitude >= minLng &&
          area.longitude <= maxLng;
    }).toList();
  }

  // 3. 내 위치 주변(반경 ~500m) 금연구역 조회 (지오펜싱 및 상태 배너 판정용)
  Future<List<SmokingArea>> loadNearbyNonSmokingAreas({
    required double userLat,
    required double userLng,
    double radiusDegrees = 0.005, // 약 500m
    int limit = 50,
  }) async {
    return await loadNonSmokingAreasInBounds(
      minLat: userLat - radiusDegrees,
      maxLat: userLat + radiusDegrees,
      minLng: userLng - (radiusDegrees * 1.2),
      maxLng: userLng + (radiusDegrees * 1.2),
      limit: limit,
    );
  }

  // 로컬 assets/data/smoking_areas.json 로드
  Future<List<SmokingArea>> loadLocalSmokingAreas() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/smoking_areas.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedSmokingAreas = jsonList
          .map((item) => SmokingArea.fromJson(item, isNonSmoking: false))
          .toList();
      return _cachedSmokingAreas;
    } catch (e) {
      debugPrint('로컬 흡연구역 데이터 로딩 에러: $e');
      return [];
    }
  }

  // 로컬 assets/data/non_smoking_areas.json 로드
  Future<List<SmokingArea>> loadLocalNonSmokingAreas() async {
    if (_cachedLocalNonSmokingAreas.isNotEmpty) {
      return _cachedLocalNonSmokingAreas;
    }
    try {
      final jsonString = await rootBundle.loadString('assets/data/non_smoking_areas.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedLocalNonSmokingAreas = jsonList
          .map((item) => SmokingArea.fromJson(item, isNonSmoking: true))
          .toList();
      return _cachedLocalNonSmokingAreas;
    } catch (e) {
      debugPrint('로컬 금연구역 데이터 로딩 에러: $e');
      return [];
    }
  }
}
