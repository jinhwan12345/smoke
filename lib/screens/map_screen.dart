import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import '../models/district_region.dart';
import '../models/smoking_area.dart';
import '../services/location_service.dart';
import '../services/smoking_area_service.dart';
import '../services/update_service.dart';
import '../theme/sketch_theme.dart';
import '../widgets/status_banner.dart';
import '../widgets/area_detail_sheet.dart';
import '../widgets/update_dialog.dart';
import '../widgets/sketch_widgets.dart';

enum AreaFilterType {
  all,
  smokingOnly,
  nonSmokingOnly,
}

class MapScreen extends StatefulWidget {
  final Position? initialPosition;

  const MapScreen({
    super.key,
    this.initialPosition,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SmokingAreaService _areaService = SmokingAreaService();

  // 줌 단계별 표시 기준
  // - 11.0 미만: 17개 광역시·도 통합 클러스터 배지
  // - 11.0 이상 ~ 15.0 미만: 229개 시·군·구 클러스터 배지
  // - 15.0 이상: 개별 흡연구역 / 금연구역 마커
  static const double kMinDistrictZoom = 11.0;
  static const double kMinAreaZoom = 15.0;

  // 종이 지도처럼 아주 살짝 따뜻한 톤을 입히는 컬러 매트릭스 (가독성 유지)
  static const ColorFilter _warmPaperMapFilter = ColorFilter.matrix(<double>[
    0.98, 0.02, 0.00, 0, 4,
    0.01, 0.96, 0.01, 0, 2,
    0.00, 0.02, 0.89, 0, -2,
    0.00, 0.00, 0.00, 1, 0,
  ]);

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  Position? _lastNearbyFetchPosition; // 내 위치 주변 구역을 마지막으로 조회한 GPS 좌표
  bool _isFetchingNearby = false;

  // 내 실제 위치(GPS) 주변 구역 (상단 상태 배너 및 지오펜싱 판정 전용 — 지도 이동에 영향받지 않음)
  List<SmokingArea> _nearbySmokingAreas = [];
  List<SmokingArea> _nearbyNonSmokingAreas = [];

  // 현재 지도 화면(Viewport BBox) 내 구역 (지도 마커/원형 반경 렌더링 전용)
  List<SmokingArea> _visibleSmokingAreas = [];
  List<SmokingArea> _visibleNonSmokingAreas = [];

  List<DistrictRegion> _visibleRegions = [];   // 중간 축소 시 현재 화면에 보이는 시·군·구 목록
  List<ProvinceRegion> _visibleProvinces = []; // 많이 축소 시 현재 화면에 보이는 광역시·도 목록

  // 내 위치 주변 구역을 다시 조회할 이동 임계 거리 (미터)
  static const double kNearbyRefetchDistanceMeters = 250.0;

  LocationCheckResult? _checkResult;
  bool _isLoading = true;
  double _currentRotation = 0.0;
  double _currentZoom = 17.0;

  AreaFilterType _currentFilter = AreaFilterType.all;
  Timer? _boundsDebounceTimer;
  int _viewportFetchSeq = 0; // 빠른 지도 이동 시 이전 느린 응답이 최신 화면을 덮어쓰는 것 방지

  AnimationController? _rotationAnimationController;
  Animation<double>? _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. 위치 권한 및 초기 위치 설정
    await LocationService.requestLocationPermission();
    Position initialPos = widget.initialPosition ?? await LocationService.getCurrentPosition();
    _currentPosition = initialPos;

    // 2. 스플래시에서 사전 로딩해 둔 내 주변 데이터가 있으면 대기 없이 즉시(0ms) 사용
    final preloaded = _areaService.takePreloadedNearby(
      initialPos.latitude,
      initialPos.longitude,
    );
    final nearby = preloaded ??
        await _areaService.loadNearbyAreas(
          userLat: initialPos.latitude,
          userLng: initialPos.longitude,
        );
    _lastNearbyFetchPosition = initialPos;
    _nearbySmokingAreas = nearby.smoking;
    _nearbyNonSmokingAreas = nearby.nonSmoking;

    // 초기 화면도 내 위치 중심이므로 마커 초기값으로 우선 채움
    _visibleSmokingAreas = nearby.smoking;
    _visibleNonSmokingAreas = nearby.nonSmoking;

    _evaluateUserLocation(initialPos);

    setState(() {
      _isLoading = false;
    });

    // 3. 실시간 위치 추적 리스너
    _positionStream = LocationService.getPositionStream().listen((pos) {
      _currentPosition = pos;
      _evaluateUserLocation(pos);
      _maybeRefreshNearbyAreas(pos);
    });

    // 4. 첫 화면 Bounding Box 내 흡연/금연구역 로드 및 전국 지역별 구역 수 요약 캐싱
    _areaService.loadAllDistrictCounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchVisibleAreas();
      _checkAppUpdate();
    });
  }

  // 사용자가 실제로 일정 거리(250m) 이상 이동했을 때만 내 주변 구역 목록 재조회
  Future<void> _maybeRefreshNearbyAreas(Position pos) async {
    if (_isFetchingNearby) return;
    if (_lastNearbyFetchPosition != null) {
      final moved = Geolocator.distanceBetween(
        _lastNearbyFetchPosition!.latitude,
        _lastNearbyFetchPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (moved < kNearbyRefetchDistanceMeters) return;
    }

    _isFetchingNearby = true;
    try {
      final nearby = await _areaService.loadNearbyAreas(
        userLat: pos.latitude,
        userLng: pos.longitude,
      );
      _lastNearbyFetchPosition = pos;
      if (mounted) {
        _nearbySmokingAreas = nearby.smoking;
        _nearbyNonSmokingAreas = nearby.nonSmoking;
        _evaluateUserLocation(_currentPosition ?? pos);
      }
    } finally {
      _isFetchingNearby = false;
    }
  }

  Future<void> _checkAppUpdate() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(updateInfo: updateInfo),
      );
    }
  }

  // 사용자 위치 평가 (지오펜싱) — 항상 '내 실제 위치 주변 구역'만 기준으로 판정
  void _evaluateUserLocation(Position position) {
    final combined = <SmokingArea>[..._nearbySmokingAreas, ..._nearbyNonSmokingAreas];
    setState(() {
      _checkResult = LocationService.evaluateLocation(
        userLat: position.latitude,
        userLng: position.longitude,
        areas: combined,
      );
    });
  }

  // 지도 이동/줌 변경 시 처리 (Debounce 300ms)
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && _rotationAnimationController?.isAnimating == true) {
      _rotationAnimationController?.stop();
    }

    if ((_currentRotation - camera.rotation).abs() > 0.01) {
      setState(() {
        _currentRotation = camera.rotation;
      });
    }

    final prevZoom = _currentZoom;
    _currentZoom = camera.zoom;

    if (_currentZoom >= kMinAreaZoom) {
      // 1단계 (줌 15.0 이상): 개별 흡연/금연구역 마커 표시
      // 먼저 타일 캐시에 있는 구역을 디바운스 없이 즉시(0ms) 반영
      final allCached = _applyCachedVisibleAreas(camera.visibleBounds);

      if (prevZoom < kMinAreaZoom || _visibleRegions.isNotEmpty || _visibleProvinces.isNotEmpty) {
        setState(() {
          _visibleRegions = [];
          _visibleProvinces = [];
        });
      }

      _boundsDebounceTimer?.cancel();
      // 현재 화면의 모든 타일이 이미 캐시에 있다면 네트워크 요청 자체를 생략!
      if (!allCached) {
        _boundsDebounceTimer = Timer(const Duration(milliseconds: 150), () {
          _fetchVisibleAreas();
        });
      }
    } else if (_currentZoom >= kMinDistrictZoom) {
      // 2단계 (줌 11.0 이상 ~ 15.0 미만): 시·군·구 클러스터 배지 표시
      if (_visibleSmokingAreas.isNotEmpty ||
          _visibleNonSmokingAreas.isNotEmpty ||
          _visibleProvinces.isNotEmpty ||
          prevZoom >= kMinAreaZoom ||
          prevZoom < kMinDistrictZoom) {
        setState(() {
          _visibleSmokingAreas = [];
          _visibleNonSmokingAreas = [];
          _visibleProvinces = [];
        });
      }
      _updateVisibleDistrictsImmediate(camera);
      _boundsDebounceTimer?.cancel();
      _boundsDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        _fetchVisibleDistrictCounts();
      });
    } else {
      // 3단계 (줌 11.0 미만): 17개 광역시·도 통합 클러스터 배지 표시
      if (_visibleSmokingAreas.isNotEmpty ||
          _visibleNonSmokingAreas.isNotEmpty ||
          _visibleRegions.isNotEmpty ||
          prevZoom >= kMinDistrictZoom) {
        setState(() {
          _visibleSmokingAreas = [];
          _visibleNonSmokingAreas = [];
          _visibleRegions = [];
        });
      }
      _updateVisibleProvincesImmediate(camera);
      _boundsDebounceTimer?.cancel();
      _boundsDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        _fetchVisibleDistrictCounts();
      });
    }
  }

  void _updateVisibleDistrictsImmediate(MapCamera camera) {
    final bounds = camera.visibleBounds;

    final inView = kKoreaDistricts.where((d) {
      return d.latitude >= bounds.south &&
          d.latitude <= bounds.north &&
          d.longitude >= bounds.west &&
          d.longitude <= bounds.east;
    }).toList();

    setState(() {
      _visibleRegions = inView;
    });
  }

  void _updateVisibleProvincesImmediate(MapCamera camera) {
    final bounds = camera.visibleBounds;

    final inView = kKoreaProvinces.where((p) {
      return p.latitude >= bounds.south &&
          p.latitude <= bounds.north &&
          p.longitude >= bounds.west &&
          p.longitude <= bounds.east;
    }).toList();

    setState(() {
      _visibleProvinces = inView;
    });
  }

  Future<void> _fetchVisibleDistrictCounts() async {
    if (_currentZoom >= kMinAreaZoom) return;
    if (_areaService.cachedRegionCounts.length >= kKoreaDistricts.length) return;

    final loaded = await _areaService.loadAllDistrictCounts();
    if (loaded && mounted && _currentZoom < kMinAreaZoom) {
      setState(() {});
    }
  }

  // 현재 필터 기준으로 캐시된 타일 데이터를 즉시(0ms) 화면에 반영
  // 반환값: 필요한 모든 타일이 이미 캐시에 존재하는지 여부
  bool _applyCachedVisibleAreas(LatLngBounds bounds) {
    final needSmoking = _currentFilter != AreaFilterType.nonSmokingOnly;
    final needNonSmoking = _currentFilter != AreaFilterType.smokingOnly;

    final smokingCache = needSmoking
        ? _areaService.getCachedAreasInBounds(
            isNonSmoking: false,
            minLat: bounds.south,
            maxLat: bounds.north,
            minLng: bounds.west,
            maxLng: bounds.east,
            limit: 150,
          )
        : (areas: _visibleSmokingAreas, allTilesCached: true);

    final nonSmokingCache = needNonSmoking
        ? _areaService.getCachedAreasInBounds(
            isNonSmoking: true,
            minLat: bounds.south,
            maxLat: bounds.north,
            minLng: bounds.west,
            maxLng: bounds.east,
            limit: 150,
          )
        : (areas: _visibleNonSmokingAreas, allTilesCached: true);

    if (smokingCache.areas.isNotEmpty ||
        nonSmokingCache.areas.isNotEmpty ||
        (smokingCache.allTilesCached && nonSmokingCache.allTilesCached)) {
      setState(() {
        if (needSmoking) _visibleSmokingAreas = smokingCache.areas;
        if (needNonSmoking) _visibleNonSmokingAreas = nonSmokingCache.areas;
      });
    }

    return smokingCache.allTilesCached && nonSmokingCache.allTilesCached;
  }

  Future<void> _fetchVisibleAreas() async {
    if (_currentZoom < kMinAreaZoom) return;

    final seq = ++_viewportFetchSeq;
    final bounds = _mapController.camera.visibleBounds;
    final minLat = bounds.south;
    final maxLat = bounds.north;
    final minLng = bounds.west;
    final maxLng = bounds.east;

    final needSmoking = _currentFilter != AreaFilterType.nonSmokingOnly;
    final needNonSmoking = _currentFilter != AreaFilterType.smokingOnly;

    final futures = await Future.wait([
      needSmoking
          ? _areaService.loadSmokingAreasInBounds(
              minLat: minLat,
              maxLat: maxLat,
              minLng: minLng,
              maxLng: maxLng,
              limit: 150,
            )
          : Future.value(_visibleSmokingAreas),
      needNonSmoking
          ? _areaService.loadNonSmokingAreasInBounds(
              minLat: minLat,
              maxLat: maxLat,
              minLng: minLng,
              maxLng: maxLng,
              limit: 150,
            )
          : Future.value(_visibleNonSmokingAreas),
    ]);

    // 최신 요청이 아니면(이미 지도가 다른 곳으로 이동했으면) 무시
    if (mounted && _currentZoom >= kMinAreaZoom && seq == _viewportFetchSeq) {
      setState(() {
        if (needSmoking) _visibleSmokingAreas = futures[0];
        if (needNonSmoking) _visibleNonSmokingAreas = futures[1];
      });
    }
  }

  void _moveToPointAndLoadAreas(LatLng target, double zoom) {
    _boundsDebounceTimer?.cancel();
    setState(() {
      _currentZoom = zoom;
      _visibleRegions = [];
      _visibleProvinces = [];
    });
    _mapController.move(target, zoom);
    final allCached = _applyCachedVisibleAreas(_mapController.camera.visibleBounds);
    if (!allCached) {
      _fetchVisibleAreas();
    }
  }

  void _moveToUserLocation() {
    if (_currentPosition != null) {
      _moveToPointAndLoadAreas(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        17.0,
      );
    }
  }

  void _resetRotation() {
    final startRotation = _mapController.camera.rotation;

    double normalizedStart = startRotation % 360.0;
    if (normalizedStart > 180.0) {
      normalizedStart -= 360.0;
    } else if (normalizedStart < -180.0) {
      normalizedStart += 360.0;
    }

    if (normalizedStart.abs() < 0.1) {
      _mapController.rotate(0.0);
      setState(() {
        _currentRotation = 0.0;
      });
      return;
    }

    _rotationAnimationController?.dispose();
    _rotationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _rotationAnimation = Tween<double>(
      begin: normalizedStart,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _rotationAnimationController!,
      curve: Curves.easeOutCubic,
    ));

    _rotationAnimation!.addListener(() {
      if (_rotationAnimation != null) {
        _mapController.rotate(_rotationAnimation!.value);
        setState(() {
          _currentRotation = _rotationAnimation!.value;
        });
      }
    });

    _rotationAnimationController!.forward();
  }

  void _showAreaDetails(SmokingArea area) {
    double? dist;
    if (_currentPosition != null) {
      dist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        area.latitude,
        area.longitude,
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AreaDetailSheet(
        area: area,
        distanceInMeters: dist,
      ),
    );
  }

  List<SmokingArea> get _displayedAreas {
    if (_currentZoom < kMinAreaZoom) return [];

    switch (_currentFilter) {
      case AreaFilterType.smokingOnly:
        return _visibleSmokingAreas;
      case AreaFilterType.nonSmokingOnly:
        return _visibleNonSmokingAreas;
      case AreaFilterType.all:
        return [..._visibleSmokingAreas, ..._visibleNonSmokingAreas];
    }
  }

  @override
  void dispose() {
    _boundsDebounceTimer?.cancel();
    _positionStream?.cancel();
    _rotationAnimationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userPos = _currentPosition;
    final userLatLng = userPos != null
        ? LatLng(userPos.latitude, userPos.longitude)
        : const LatLng(35.90682384, 128.62055516);

    final isClusterMode = _currentZoom < kMinAreaZoom;

    return Scaffold(
      backgroundColor: SketchColors.paper,
      body: _isLoading
          ? NotebookPaperBackground(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: SketchColors.ink),
                    const SizedBox(height: 14),
                    Text(
                      '지도를 그리는 중...',
                      style: SketchTextStyles.title(size: 22),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                // 1. 메인 지도 (전체화면)
                _buildMapView(userLatLng),

                // 2. 상단 상태 배너 & 손그림 필터 칩
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusBanner(
                                checkResult: _checkResult,
                                onTap: () {
                                  final targetArea = _checkResult?.isInsideSmokingArea == true
                                      ? _checkResult?.currentSmokingArea
                                      : _checkResult?.isInsideNonSmokingArea == true
                                          ? _checkResult?.currentNonSmokingArea
                                          : _checkResult?.nearestSmokingArea;
                                  if (targetArea != null) {
                                    _moveToPointAndLoadAreas(
                                      LatLng(targetArea.latitude, targetArea.longitude),
                                      17.5,
                                    );
                                    _showAreaDetails(targetArea);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildFilterChips(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. 지도를 축소했을 때 손그림 안내 말풍선
                if (isClusterMode)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 84,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Transform.rotate(
                        angle: -0.012,
                        child: SketchBox(
                          fillColor: SketchColors.paperWarm,
                          borderColor: SketchColors.ink,
                          shadowColor: SketchColors.ink,
                          strokeWidth: 2.0,
                          cornerRadius: 16,
                          shadowOffset: const Offset(3, 3.5),
                          seed: 205,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SketchIcon(
                                glyph: SketchGlyph.touch,
                                size: 18,
                                color: SketchColors.smokeAmber,
                                strokeWidth: 2.2,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  _currentZoom < kMinDistrictZoom
                                      ? '시·도 스티커를 누르면 시·군·구로 확대돼요!'
                                      : '시·군·구 스티커를 누르면 구역이 보여요!',
                                  style: SketchTextStyles.label(
                                    size: 14.5,
                                    color: SketchColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. 방위 정렬(손그림 나침반) 버튼 (SafeArea 상단 여백 반영해 노치 기기 겹침 방지)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 148,
                  right: 16,
                  child: Tooltip(
                    message: '북쪽 맞추기',
                    child: _buildCompassButton(),
                  ),
                ),

                // 5. 우측 하단 손그림 줌 / 내 위치 컨트롤 버튼
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: '확대',
                          child: SketchCircle(
                            size: 46,
                            fillColor: SketchColors.paper,
                            borderColor: SketchColors.ink,
                            strokeWidth: 2.2,
                            shadowOffset: const Offset(2.5, 3),
                            seed: 301,
                            onTap: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(_mapController.camera.center, currentZoom + 1);
                            },
                            child: const SketchIcon(
                              glyph: SketchGlyph.plus,
                              size: 20,
                              color: SketchColors.ink,
                              strokeWidth: 2.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Tooltip(
                          message: '축소',
                          child: SketchCircle(
                            size: 46,
                            fillColor: SketchColors.paper,
                            borderColor: SketchColors.ink,
                            strokeWidth: 2.2,
                            shadowOffset: const Offset(2.5, 3),
                            seed: 302,
                            onTap: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(_mapController.camera.center, currentZoom - 1);
                            },
                            child: const SketchIcon(
                              glyph: SketchGlyph.minus,
                              size: 20,
                              color: SketchColors.ink,
                              strokeWidth: 2.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Tooltip(
                          message: '내 위치로 이동',
                          child: SketchCircle(
                            size: 56,
                            fillColor: SketchColors.smokeYellow,
                            borderColor: SketchColors.ink,
                            strokeWidth: 2.5,
                            shadowOffset: const Offset(3, 4),
                            seed: 303,
                            onTap: _moveToUserLocation,
                            child: const SketchIcon(
                              glyph: SketchGlyph.target,
                              size: 26,
                              color: SketchColors.ink,
                              strokeWidth: 2.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildChip(
              label: '전체보기',
              filterType: AreaFilterType.all,
              selectedFill: SketchColors.ink,
              selectedText: SketchColors.paper,
              borderColor: SketchColors.ink,
              angle: -0.015,
              seed: 401,
            ),
            const SizedBox(width: 10),
            _buildChip(
              label: '흡연구역',
              iconAsset: 'assets/images/doodle_smoke.png',
              filterType: AreaFilterType.smokingOnly,
              selectedFill: SketchColors.smokeYellow,
              selectedText: SketchColors.ink,
              borderColor: SketchColors.smokeAmber,
              angle: 0.014,
              seed: 402,
            ),
            const SizedBox(width: 10),
            _buildChip(
              label: '금연구역',
              iconAsset: 'assets/images/doodle_no_smoke.png',
              filterType: AreaFilterType.nonSmokingOnly,
              selectedFill: SketchColors.noSmokeFill,
              selectedText: SketchColors.noSmokeDark,
              borderColor: SketchColors.noSmokeRed,
              angle: -0.012,
              seed: 403,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    String? iconAsset,
    required AreaFilterType filterType,
    required Color selectedFill,
    required Color selectedText,
    required Color borderColor,
    required double angle,
    required int seed,
  }) {
    final isSelected = _currentFilter == filterType;
    return Transform.rotate(
      angle: angle,
      child: SketchBox(
        fillColor: isSelected ? selectedFill : SketchColors.paper,
        borderColor: isSelected ? SketchColors.ink : borderColor,
        shadowColor: SketchColors.ink,
        strokeWidth: isSelected ? 2.3 : 1.7,
        cornerRadius: 18,
        shadowOffset: isSelected ? const Offset(2.5, 3.0) : const Offset(1.5, 2.0),
        doubleStroke: isSelected,
        seed: seed,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () {
          setState(() {
            _currentFilter = filterType;
          });
          // 필터 전환 시 아직 불러오지 않은 테이블 데이터가 있으면 즉시 조회
          if (_currentZoom >= kMinAreaZoom) {
            final allCached = _applyCachedVisibleAreas(_mapController.camera.visibleBounds);
            if (!allCached) {
              _fetchVisibleAreas();
            }
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              Image.asset(
                iconAsset,
                width: 19,
                height: 19,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: SketchTextStyles.label(
                size: 15.5,
                color: isSelected ? selectedText : SketchColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(LatLng userLatLng) {
    final displayAreas = _displayedAreas;
    final isClusterMode = _currentZoom < kMinAreaZoom;
    final isProvinceMode = _currentZoom < kMinDistrictZoom;
    final isDistrictMode = _currentZoom >= kMinDistrictZoom && _currentZoom < kMinAreaZoom;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userLatLng,
        initialZoom: 17.0,
        minZoom: 6.0,
        maxZoom: 19.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
          enableMultiFingerGestureRace: true,
          pinchZoomThreshold: 0.12,
          pinchZoomWinGestures: MultiFingerGesture.pinchZoom | MultiFingerGesture.pinchMove,
          rotationThreshold: 15.0,
          rotationWinGestures: MultiFingerGesture.rotate,
        ),
        onPositionChanged: _onMapPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.smoke_finder',
          tileProvider: NetworkTileProvider(),
          tileBuilder: (context, tileWidget, tile) {
            return ColorFiltered(
              colorFilter: _warmPaperMapFilter,
              child: tileWidget,
            );
          },
        ),

        // 원형 반경 레이어 (색연필/형광펜 느낌의 파스텔 원)
        if (!isClusterMode)
          CircleLayer(
            circles: displayAreas.map((area) {
              final isInsideSmoking = _checkResult?.currentSmokingArea?.id == area.id;
              final isInsideNonSmoking = _checkResult?.currentNonSmokingArea?.id == area.id;

              if (area.isNonSmoking) {
                return CircleMarker(
                  point: LatLng(area.latitude, area.longitude),
                  radius: area.radius,
                  useRadiusInMeter: true,
                  color: isInsideNonSmoking
                      ? SketchColors.noSmokeRed.withOpacity(0.36)
                      : SketchColors.noSmokeRed.withOpacity(0.16),
                  borderColor: SketchColors.noSmokeRed,
                  borderStrokeWidth: isInsideNonSmoking ? 3.2 : 1.8,
                );
              } else {
                return CircleMarker(
                  point: LatLng(area.latitude, area.longitude),
                  radius: area.radius,
                  useRadiusInMeter: true,
                  color: isInsideSmoking
                      ? SketchColors.safeGreen.withOpacity(0.38)
                      : SketchColors.smokeYellow.withOpacity(0.32),
                  borderColor: isInsideSmoking ? SketchColors.safeGreen : SketchColors.smokeAmber,
                  borderStrokeWidth: isInsideSmoking ? 3.2 : 1.8,
                );
              }
            }).toList(),
          ),

        // 마커 레이어 (내 위치 + 3단계 줌 레벨별 손그림 배지/마커)
        MarkerLayer(
          rotate: true,
          markers: [
            Marker(
              point: userLatLng,
              width: 52,
              height: 52,
              rotate: true,
              child: _buildUserLocationMarker(),
            ),

            // 1. 많이 축소 시 (zoom < 11.0): 17개 광역시·도 통합 클러스터 스티커
            if (isProvinceMode)
              ..._visibleProvinces.map((province) {
                final counts = _areaService.getProvinceCounts(province.sidoKey);
                return Marker(
                  point: LatLng(province.latitude, province.longitude),
                  width: 136,
                  height: 68,
                  rotate: true,
                  child: _buildProvinceClusterBadge(province, counts),
                );
              }),

            // 2. 중간 축소 시 (11.0 <= zoom < 15.0): 시·군·구 클러스터 스티커
            if (isDistrictMode)
              ..._visibleRegions.map((region) {
                final counts = _areaService.cachedRegionCounts[region.code];
                return Marker(
                  point: LatLng(region.latitude, region.longitude),
                  width: 130,
                  height: 66,
                  rotate: true,
                  child: _buildDistrictClusterBadge(region, counts),
                );
              }),

            // 3. 확대 시 (zoom >= 15.0): 개별 흡연구역 / 금연구역 손그림 마커
            if (!isClusterMode)
              ...displayAreas.map((area) {
                final isCurrent = area.isNonSmoking
                    ? _checkResult?.currentNonSmokingArea?.id == area.id
                    : _checkResult?.currentSmokingArea?.id == area.id;

                final borderColor = area.isNonSmoking
                    ? (isCurrent ? SketchColors.noSmokeDark : SketchColors.noSmokeRed)
                    : (isCurrent ? SketchColors.safeGreen : SketchColors.smokeAmber);

                final fillColor = isCurrent
                    ? (area.isNonSmoking ? SketchColors.noSmokeFill : SketchColors.safeFill)
                    : SketchColors.paper;

                final iconAsset = area.isNonSmoking
                    ? 'assets/images/doodle_no_smoke.png'
                    : 'assets/images/doodle_smoke.png';

                final fallbackIcon = area.isNonSmoking
                    ? Icons.smoke_free
                    : Icons.smoking_rooms;

                return Marker(
                  point: LatLng(area.latitude, area.longitude),
                  width: isCurrent ? 54 : 48,
                  height: isCurrent ? 54 : 48,
                  rotate: true,
                  child: SketchCircle(
                    size: isCurrent ? 50 : 44,
                    fillColor: fillColor,
                    borderColor: borderColor,
                    shadowColor: SketchColors.ink,
                    strokeWidth: isCurrent ? 2.8 : 2.1,
                    shadowOffset: const Offset(2, 2.5),
                    seed: area.id.hashCode,
                    onTap: () => _showAreaDetails(area),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Image.asset(
                        iconAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          fallbackIcon,
                          color: borderColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  // 광역시·도 손그림 스티커 배지 (줌 11.0 미만)
  Widget _buildProvinceClusterBadge(
    ProvinceRegion province,
    ({int smokingCount, int nonSmokingCount})? counts,
  ) {
    final borderColor = switch (_currentFilter) {
      AreaFilterType.smokingOnly => SketchColors.smokeAmber,
      AreaFilterType.nonSmokingOnly => SketchColors.noSmokeRed,
      AreaFilterType.all => SketchColors.ink,
    };

    return Center(
      child: SketchBox(
        fillColor: SketchColors.paper,
        borderColor: borderColor,
        shadowColor: SketchColors.ink,
        strokeWidth: 2.0,
        cornerRadius: 14,
        shadowOffset: const Offset(2.5, 3.0),
        doubleStroke: false,
        seed: province.sidoKey.hashCode,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        onTap: () {
          _mapController.move(
            LatLng(province.latitude, province.longitude),
            province.targetZoom,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              province.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SketchTextStyles.label(
                size: 15,
                color: SketchColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            if (counts == null)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: SketchColors.inkMuted,
                ),
              )
            else
              _buildCountRowByValues(
                smokingCount: counts.smokingCount,
                nonSmokingCount: counts.nonSmokingCount,
              ),
          ],
        ),
      ),
    );
  }

  // 시·군·구 손그림 스티커 배지 (줌 11.0 ~ 15.0 미만)
  Widget _buildDistrictClusterBadge(DistrictRegion region, RegionCounts? counts) {
    final borderColor = switch (_currentFilter) {
      AreaFilterType.smokingOnly => SketchColors.smokeAmber,
      AreaFilterType.nonSmokingOnly => SketchColors.noSmokeRed,
      AreaFilterType.all => SketchColors.ink,
    };

    return Center(
      child: SketchBox(
        fillColor: SketchColors.paperWarm,
        borderColor: borderColor,
        shadowColor: SketchColors.ink,
        strokeWidth: 1.9,
        cornerRadius: 13,
        shadowOffset: const Offset(2, 2.5),
        doubleStroke: false,
        seed: region.code.hashCode,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        onTap: () {
          _moveToPointAndLoadAreas(
            LatLng(region.latitude, region.longitude),
            15.5,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              region.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SketchTextStyles.label(
                size: 14.5,
                color: SketchColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            if (counts == null)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: SketchColors.inkMuted,
                ),
              )
            else
              _buildCountRowByValues(
                smokingCount: counts.smokingCount,
                nonSmokingCount: counts.nonSmokingCount,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountRowByValues({
    required int smokingCount,
    required int nonSmokingCount,
  }) {
    Widget miniIcon(String asset) => Image.asset(
          asset,
          width: 14,
          height: 14,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        );

    switch (_currentFilter) {
      case AreaFilterType.smokingOnly:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            miniIcon('assets/images/doodle_smoke.png'),
            const SizedBox(width: 3),
            Text(
              _formatCount(smokingCount),
              style: SketchTextStyles.label(
                size: 13.5,
                color: SketchColors.smokeAmber,
              ),
            ),
          ],
        );
      case AreaFilterType.nonSmokingOnly:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            miniIcon('assets/images/doodle_no_smoke.png'),
            const SizedBox(width: 3),
            Text(
              _formatCount(nonSmokingCount),
              style: SketchTextStyles.label(
                size: 13.5,
                color: SketchColors.noSmokeRed,
              ),
            ),
          ],
        );
      case AreaFilterType.all:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            miniIcon('assets/images/doodle_smoke.png'),
            const SizedBox(width: 2),
            Text(
              _formatCount(smokingCount),
              style: SketchTextStyles.label(
                size: 13,
                color: SketchColors.smokeAmber,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                '/',
                style: SketchTextStyles.label(
                  size: 12,
                  color: SketchColors.inkLight,
                ),
              ),
            ),
            miniIcon('assets/images/doodle_no_smoke.png'),
            const SizedBox(width: 2),
            Text(
              _formatCount(nonSmokingCount),
              style: SketchTextStyles.label(
                size: 13,
                color: SketchColors.noSmokeRed,
              ),
            ),
          ],
        );
    }
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Widget _buildCompassButton() {
    return SketchCircle(
      size: 46,
      fillColor: SketchColors.paper,
      borderColor: SketchColors.ink,
      strokeWidth: 2.2,
      shadowOffset: const Offset(2.5, 3),
      seed: 501,
      onTap: _resetRotation,
      child: Transform.rotate(
        angle: _currentRotation * (math.pi / 180.0),
        child: CustomPaint(
          size: const Size(28, 28),
          painter: _SketchCompassNeedlePainter(),
        ),
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SketchCircle(
          size: 40,
          fillColor: SketchColors.bluePen.withOpacity(0.18),
          borderColor: SketchColors.bluePen.withOpacity(0.65),
          shadowOffset: Offset.zero,
          strokeWidth: 1.6,
          seed: 601,
          child: const SizedBox(),
        ),
        SketchCircle(
          size: 20,
          fillColor: SketchColors.bluePen,
          borderColor: SketchColors.paper,
          shadowColor: SketchColors.ink,
          shadowOffset: const Offset(1.5, 2),
          strokeWidth: 2.4,
          seed: 602,
          child: const SizedBox(),
        ),
      ],
    );
  }
}

/// 자 없이 펜으로 대충 그린 나침반 바늘
class _SketchCompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final hw = size.width * 0.24;

    // 북쪽(빨간 사인펜 칠하기)
    final northPath = Path()
      ..moveTo(cx + 0.5, 2)
      ..lineTo(cx + hw, cy + 0.5)
      ..lineTo(cx - hw + 0.5, cy - 0.5)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()
        ..color = SketchColors.noSmokeRed
        ..style = PaintingStyle.fill,
    );

    // 남쪽(연필 회색)
    final southPath = Path()
      ..moveTo(cx - 0.5, size.height - 2)
      ..lineTo(cx + hw, cy + 0.5)
      ..lineTo(cx - hw + 0.5, cy - 0.5)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()
        ..color = SketchColors.paperWarm
        ..style = PaintingStyle.fill,
    );

    // 검정 펜 외곽선
    final outline = Paint()
      ..color = SketchColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(northPath, outline);
    canvas.drawPath(southPath, outline);

    // 중앙 점
    canvas.drawCircle(
      Offset(cx, cy),
      2.6,
      Paint()..color = SketchColors.paper,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      2.6,
      outline..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
