import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/district_region.dart';
import '../models/smoking_area.dart';

class SmokingAreaService {
  // 싱글톤: SplashScreen(사전 로딩)과 MapScreen이 HTTP 연결 및 공간 캐시를 공유
  static final SmokingAreaService _instance = SmokingAreaService._internal();
  factory SmokingAreaService() => _instance;
  SmokingAreaService._internal();

  static const String supabaseUrl = 'https://cqtojdswnwgshqhnwzmg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_4nbwJnVgf34sKrCKpNsSTQ_zy8QudVU';

  static const Map<String, String> _headers = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey',
  };

  // 필요한 컬럼만 명시하여 페이로드 경량화
  static const String _areaColumns =
      'id,area_nm,area_ar,latitude,longitude,lnmadr,rdnmadr,ref_date';

  // Keep-Alive HTTP Client 재사용 (매 요청마다 TCP/TLS 핸드셰이크 생략)
  final http.Client _client = http.Client();

  // 격자 타일 크기 (도 단위)
  // - 흡연구역: 밀도가 낮아 0.02°(약 2.2km) 단위로 넓게 캐싱
  // - 금연구역: 도심 밀도가 높아 0.008°(약 880m) 단위로 캐싱
  static const double _smokingTileDeg = 0.02;
  static const double _nonSmokingTileDeg = 0.008;
  static const int _maxCachedTiles = 140;

  // 공간 타일 LRU 캐시 (LinkedHashMap으로 오래된 타일 자동 정리)
  final LinkedHashMap<String, List<SmokingArea>> _smokingTileCache = LinkedHashMap();
  final LinkedHashMap<String, List<SmokingArea>> _nonSmokingTileCache = LinkedHashMap();

  // 동일 타일 중복 네트워크 요청 방지
  final Map<String, Future<List<SmokingArea>>> _inFlightTileRequests = {};

  // 지역(시·군·구)별 흡연/금연구역 개수 메모리 캐시
  final Map<String, RegionCounts> _regionCountsCache = {};
  Future<bool>? _loadingAllCountsFuture;

  // 스플래시 화면에서 사전 로딩한 초기 내 주변 결과 보관
  ({double lat, double lng, List<SmokingArea> smoking, List<SmokingArea> nonSmoking})?
      _preloadedNearby;

  Map<String, RegionCounts> get cachedRegionCounts => _regionCountsCache;

  /// 스플래시 대기 시간(2.2초) 동안 내 주변 구역 + 전국 시·군·구 개수를 백그라운드 사전 로딩
  Future<void> preloadInitialData({
    required double userLat,
    required double userLng,
  }) async {
    try {
      final results = await Future.wait([
        loadNearbyAreas(userLat: userLat, userLng: userLng),
        loadAllDistrictCounts(),
      ]);
      final nearby = results[0] as ({List<SmokingArea> smoking, List<SmokingArea> nonSmoking});
      _preloadedNearby = (
        lat: userLat,
        lng: userLng,
        smoking: nearby.smoking,
        nonSmoking: nearby.nonSmoking,
      );
    } catch (e) {
      debugPrint('초기 데이터 사전 로딩 중 무시된 오류: $e');
    }
  }

  /// 스플래시에서 사전 로딩해 둔 내 주변 결과가 동일 좌표 근처에 있으면 즉시 소비
  ({List<SmokingArea> smoking, List<SmokingArea> nonSmoking})? takePreloadedNearby(
    double userLat,
    double userLng,
  ) {
    final pre = _preloadedNearby;
    if (pre == null) return null;
    if ((pre.lat - userLat).abs() < 0.001 && (pre.lng - userLng).abs() < 0.001) {
      _preloadedNearby = null;
      return (smoking: pre.smoking, nonSmoking: pre.nonSmoking);
    }
    return null;
  }

  // 타일 좌표 계산 헬퍼
  List<({int x, int y, String key})> _getTilesForBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required double tileDeg,
    required String prefix,
  }) {
    final minY = (minLat / tileDeg).floor();
    final maxY = (maxLat / tileDeg).floor();
    final minX = (minLng / tileDeg).floor();
    final maxX = (maxLng / tileDeg).floor();

    final tiles = <({int x, int y, String key})>[];
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        tiles.add((x: x, y: y, key: '${prefix}_${y}_$x'));
      }
    }
    return tiles;
  }

  void _putTileCache(
    LinkedHashMap<String, List<SmokingArea>> cache,
    String key,
    List<SmokingArea> areas,
  ) {
    cache.remove(key);
    cache[key] = areas;
    while (cache.length > _maxCachedTiles) {
      cache.remove(cache.keys.first);
    }
  }

  // Raw Bounding Box HTTP 조회 (네트워크 오류/타임아웃 시 null 반환 → 빈 캐시 오염 방지)
  Future<List<SmokingArea>?> _fetchRawBounds({
    required String table,
    required bool isNonSmoking,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 200,
  }) async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/$table?'
        'select=$_areaColumns&'
        'latitude=gte.${minLat.toStringAsFixed(6)}&latitude=lte.${maxLat.toStringAsFixed(6)}&'
        'longitude=gte.${minLng.toStringAsFixed(6)}&longitude=lte.${maxLng.toStringAsFixed(6)}&'
        'limit=$limit',
      );

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList
            .map((item) => SmokingArea.fromJson(item, isNonSmoking: isNonSmoking))
            .toList();
      }
    } catch (e) {
      debugPrint('Supabase $table 조회 에러: $e');
    }
    return null;
  }

  // 타일 캐시를 활용한 고속 영역 조회 (캐시 히트 시 0ms, 미스 타일만 병렬 조회)
  Future<List<SmokingArea>> _loadAreasWithTileCache({
    required String table,
    required bool isNonSmoking,
    required double tileDeg,
    required LinkedHashMap<String, List<SmokingArea>> cache,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int limit,
  }) async {
    final prefix = isNonSmoking ? 'ns' : 's';
    final tiles = _getTilesForBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      tileDeg: tileDeg,
      prefix: prefix,
    );

    final missingTiles = tiles.where((t) => !cache.containsKey(t.key)).toList();

    // 타일이 너무 많으면(넓은 웹 데스크톱 화면 등) 단일 BBox 요청으로 폴백하여 요청 폭주 방지
    if (missingTiles.length > 6) {
      final fetched = await _fetchRawBounds(
        table: table,
        isNonSmoking: isNonSmoking,
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        limit: limit,
      );
      return fetched ?? [];
    }

    // 미캐시 타일만 병렬 요청 (이미 진행 중인 동일 타일은 Future 공유)
    if (missingTiles.isNotEmpty) {
      await Future.wait(missingTiles.map((tile) {
        return _inFlightTileRequests.putIfAbsent(tile.key, () async {
          try {
            final tMinLat = tile.y * tileDeg;
            final tMaxLat = (tile.y + 1) * tileDeg;
            final tMinLng = tile.x * tileDeg;
            final tMaxLng = (tile.x + 1) * tileDeg;
            final fetched = await _fetchRawBounds(
              table: table,
              isNonSmoking: isNonSmoking,
              minLat: tMinLat,
              maxLat: tMaxLat,
              minLng: tMinLng,
              maxLng: tMaxLng,
              limit: 200,
            );
            // 성공적으로 응답을 받은 경우에만 타일 캐시에 저장 (에러 시 재시도 가능)
            if (fetched != null) {
              _putTileCache(cache, tile.key, fetched);
              return fetched;
            }
            return <SmokingArea>[];
          } finally {
            _inFlightTileRequests.remove(tile.key);
          }
        });
      }));
    }

    return _collectFromCache(
      cache: cache,
      tiles: tiles,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: limit,
    );
  }

  List<SmokingArea> _collectFromCache({
    required LinkedHashMap<String, List<SmokingArea>> cache,
    required List<({int x, int y, String key})> tiles,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int limit,
  }) {
    final seenIds = <String>{};
    final result = <SmokingArea>[];

    for (final tile in tiles) {
      final list = cache[tile.key];
      if (list == null) continue;
      // LRU 갱신
      cache.remove(tile.key);
      cache[tile.key] = list;

      for (final area in list) {
        if (area.latitude >= minLat &&
            area.latitude <= maxLat &&
            area.longitude >= minLng &&
            area.longitude <= maxLng) {
          if (seenIds.add(area.id)) {
            result.add(area);
            if (result.length >= limit) return result;
          }
        }
      }
    }
    return result;
  }

  /// 현재 화면에 대해 이미 캐시된 구역들을 네트워크 대기 없이 즉시(0ms) 반환
  /// `allTilesCached`가 true이면 네트워크 요청 자체를 생략할 수 있음
  ({List<SmokingArea> areas, bool allTilesCached}) getCachedAreasInBounds({
    required bool isNonSmoking,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 150,
  }) {
    final tileDeg = isNonSmoking ? _nonSmokingTileDeg : _smokingTileDeg;
    final cache = isNonSmoking ? _nonSmokingTileCache : _smokingTileCache;
    final prefix = isNonSmoking ? 'ns' : 's';

    final tiles = _getTilesForBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      tileDeg: tileDeg,
      prefix: prefix,
    );

    final allCached = tiles.isNotEmpty && tiles.every((t) => cache.containsKey(t.key));
    final areas = _collectFromCache(
      cache: cache,
      tiles: tiles,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: limit,
    );
    return (areas: areas, allTilesCached: allCached);
  }

  // 1. 현재 화면 영역(Bounding Box) 내 흡연구역 조회 (타일 캐시 적용)
  Future<List<SmokingArea>> loadSmokingAreasInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 150,
  }) {
    return _loadAreasWithTileCache(
      table: 'smoking_areas',
      isNonSmoking: false,
      tileDeg: _smokingTileDeg,
      cache: _smokingTileCache,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: limit,
    );
  }

  // 2. 현재 화면 영역(Bounding Box) 내 금연구역 조회 (타일 캐시 적용)
  Future<List<SmokingArea>> loadNonSmokingAreasInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 150,
  }) {
    return _loadAreasWithTileCache(
      table: 'non_smoking_areas',
      isNonSmoking: true,
      tileDeg: _nonSmokingTileDeg,
      cache: _nonSmokingTileCache,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: limit,
    );
  }

  // 3. 내 실제 위치 주변 흡연/금연구역 조회 (지오펜싱 및 상단 상태 배너 전용)
  // - 기본 반경 약 1km 조회 후, 흡연구역이 없으면 3km -> 10km 순으로 자동 확장 탐색
  Future<({List<SmokingArea> smoking, List<SmokingArea> nonSmoking})> loadNearbyAreas({
    required double userLat,
    required double userLng,
    double radiusDegrees = 0.01, // 약 1km
    int limit = 100,
  }) async {
    Future<List<SmokingArea>> fetchSmoking(double deg) {
      return loadSmokingAreasInBounds(
        minLat: userLat - deg,
        maxLat: userLat + deg,
        minLng: userLng - (deg * 1.2),
        maxLng: userLng + (deg * 1.2),
        limit: limit,
      );
    }

    Future<List<SmokingArea>> fetchNonSmoking(double deg) {
      return loadNonSmokingAreasInBounds(
        minLat: userLat - deg,
        maxLat: userLat + deg,
        minLng: userLng - (deg * 1.2),
        maxLng: userLng + (deg * 1.2),
        limit: limit,
      );
    }

    final results = await Future.wait([
      fetchSmoking(radiusDegrees),
      fetchNonSmoking(radiusDegrees),
    ]);

    var smoking = results[0];
    final nonSmoking = results[1];

    // 내 위치 주변 1km 내에 흡연구역이 없으면 반경을 단계적으로 넓혀 가장 가까운 곳 탐색
    if (smoking.isEmpty) {
      for (final expandedDeg in [0.03, 0.1]) {
        if (expandedDeg <= radiusDegrees) continue;
        final expanded = await _fetchRawBounds(
          table: 'smoking_areas',
          isNonSmoking: false,
          minLat: userLat - expandedDeg,
          maxLat: userLat + expandedDeg,
          minLng: userLng - (expandedDeg * 1.2),
          maxLng: userLng + (expandedDeg * 1.2),
          limit: limit,
        );
        if (expanded != null && expanded.isNotEmpty) {
          smoking = expanded;
          break;
        }
      }
    }

    return (smoking: smoking, nonSmoking: nonSmoking);
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

      final response = await _client
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

    return _fallbackAggregateSmokingAreasByAddress();
  }

  Future<bool> _fallbackAggregateSmokingAreasByAddress() async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/smoking_areas?'
        'select=id,lnmadr,rdnmadr,latitude,longitude&limit=5000',
      );

      final response = await _client
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
