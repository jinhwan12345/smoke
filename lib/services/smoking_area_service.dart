import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/smoking_area.dart';

class AreaWithDistance {
  final SmokingArea area;
  final double distanceInMeters;

  AreaWithDistance({required this.area, required this.distanceInMeters});
}

class SmokingAreaService {
  List<SmokingArea> _cachedAreas = [];

  // Supabase 실시간 클라우드 DB 설정
  static const String supabaseUrl = 'https://cqtojdswnwgshqhnwzmg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_4nbwJnVgf34sKrCKpNsSTQ_zy8QudVU';

  // Supabase 클라우드 DB에서 실시간으로 흡연구역 목록 로드 (실패 시 로컬 assets 폴백)
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
          _cachedAreas = jsonList.map((item) => SmokingArea.fromJson(item)).toList();
          return _cachedAreas;
        }
      }
    } catch (e) {
      print('Supabase 통신 오류 또는 타임아웃, 로컬 데이터 사용: $e');
    }

    // Supabase 데이터가 비어있거나 실패한 경우 로컬 assets 데이터 로드
    return await loadLocalSmokingAreas();
  }

  // 로컬 assets/data/smoking_areas.json 로드
  Future<List<SmokingArea>> loadLocalSmokingAreas() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/smoking_areas.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedAreas = jsonList.map((item) => SmokingArea.fromJson(item)).toList();
      return _cachedAreas;
    } catch (e) {
      print('로컬 데이터 로딩 에러: $e');
      return [];
    }
  }

  // 현재 위치 기준 주변 반경(기본 3km) 이내의 흡연구역을 거리순 정렬하여 반환
  List<AreaWithDistance> getNearbyAreas({
    required double userLat,
    required double userLng,
    double maxDistanceInMeters = 3000.0,
  }) {
    List<AreaWithDistance> nearby = [];

    for (var area in _cachedAreas) {
      double distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        area.latitude,
        area.longitude,
      );

      if (distance <= maxDistanceInMeters) {
        nearby.add(AreaWithDistance(area: area, distanceInMeters: distance));
      }
    }

    nearby.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    return nearby;
  }
}
