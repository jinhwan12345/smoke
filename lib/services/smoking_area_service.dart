import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/smoking_area.dart';

class SmokingAreaService {
  List<SmokingArea> _cachedSmokingAreas = [];
  List<SmokingArea> _cachedNonSmokingAreas = [];

  // Supabase 실시간 클라우드 DB 설정
  static const String supabaseUrl = 'https://cqtojdswnwgshqhnwzmg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_4nbwJnVgf34sKrCKpNsSTQ_zy8QudVU';

  // 흡연구역과 금연구역을 동시에 모두 로드
  Future<List<SmokingArea>> loadAllAreas() async {
    final results = await Future.wait([
      loadSmokingAreas(),
      loadNonSmokingAreas(),
    ]);

    final allList = <SmokingArea>[];
    allList.addAll(results[0]);
    allList.addAll(results[1]);
    return allList;
  }

  // Supabase 클라우드 DB에서 흡연구역(smoking_areas) 목록 로드
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

    // 실패 또는 빈 데이터 시 로컬 assets fallback
    return await loadLocalSmokingAreas();
  }

  // Supabase 클라우드 DB에서 금연구역(non_smoking_areas) 목록 로드
  Future<List<SmokingArea>> loadNonSmokingAreas() async {
    try {
      final response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/non_smoking_areas?select=*'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        if (jsonList.isNotEmpty) {
          _cachedNonSmokingAreas = jsonList
              .map((item) => SmokingArea.fromJson(item, isNonSmoking: true))
              .toList();
          return _cachedNonSmokingAreas;
        }
      }
    } catch (e) {
      debugPrint('Supabase 금연구역 통신 오류 또는 타임아웃, 로컬 데이터 사용: $e');
    }

    // 실패 또는 빈 데이터 시 로컬 assets fallback
    return await loadLocalNonSmokingAreas();
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
    try {
      final jsonString = await rootBundle.loadString('assets/data/non_smoking_areas.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedNonSmokingAreas = jsonList
          .map((item) => SmokingArea.fromJson(item, isNonSmoking: true))
          .toList();
      return _cachedNonSmokingAreas;
    } catch (e) {
      debugPrint('로컬 금연구역 데이터 로딩 에러: $e');
      return [];
    }
  }
}
