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
import '../widgets/status_banner.dart';
import '../widgets/area_detail_sheet.dart';

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

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;

  List<SmokingArea> _smokingAreas = [];        // 현재 화면(BBox) 내 동적 흡연구역
  List<SmokingArea> _nonSmokingAreas = [];     // 현재 화면(BBox) 내 동적 금연구역
  List<DistrictRegion> _visibleRegions = [];   // 중간 축소 시 현재 화면에 보이는 시·군·구 목록
  List<ProvinceRegion> _visibleProvinces = []; // 많이 축소 시 현재 화면에 보이는 광역시·도 목록

  LocationCheckResult? _checkResult;
  bool _isLoading = true;
  double _currentRotation = 0.0;
  double _currentZoom = 17.0;

  AreaFilterType _currentFilter = AreaFilterType.all;
  Timer? _boundsDebounceTimer;

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

    // 2. 내 위치 주변 흡연/금연구역 1차 로드 (초기 지오펜싱용)
    final nearby = await _areaService.loadNearbyAreas(
      userLat: initialPos.latitude,
      userLng: initialPos.longitude,
    );
    _smokingAreas = nearby.smoking;
    _nonSmokingAreas = nearby.nonSmoking;

    _evaluateUserLocation(initialPos);

    setState(() {
      _isLoading = false;
    });

    // 3. 실시간 위치 추적 리스너
    _positionStream = LocationService.getPositionStream().listen((pos) {
      _currentPosition = pos;
      _evaluateUserLocation(pos);
    });

    // 4. 첫 화면 Bounding Box 내 흡연/금연구역 로드 및 전국 지역별 구역 수 요약 캐싱
    _areaService.loadAllDistrictCounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchVisibleAreas();
    });
  }

  // 사용자 위치 평가 (지오펜싱)
  void _evaluateUserLocation(Position position) {
    final combined = <SmokingArea>[..._smokingAreas, ..._nonSmokingAreas];
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
      if (prevZoom < kMinAreaZoom || _visibleRegions.isNotEmpty || _visibleProvinces.isNotEmpty) {
        setState(() {
          _visibleRegions = [];
          _visibleProvinces = [];
        });
      }
      _boundsDebounceTimer?.cancel();
      _boundsDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _fetchVisibleAreas();
      });
    } else if (_currentZoom >= kMinDistrictZoom) {
      // 2단계 (줌 11.0 이상 ~ 15.0 미만): 시·군·구 클러스터 배지 표시
      if (_smokingAreas.isNotEmpty ||
          _nonSmokingAreas.isNotEmpty ||
          _visibleProvinces.isNotEmpty ||
          prevZoom >= kMinAreaZoom ||
          prevZoom < kMinDistrictZoom) {
        setState(() {
          _smokingAreas = [];
          _nonSmokingAreas = [];
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
      if (_smokingAreas.isNotEmpty ||
          _nonSmokingAreas.isNotEmpty ||
          _visibleRegions.isNotEmpty ||
          prevZoom >= kMinDistrictZoom) {
        setState(() {
          _smokingAreas = [];
          _nonSmokingAreas = [];
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

  // 현재 화면에 들어오는 시·군·구 목록 즉시 계산 (중간 축소 상태)
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

  // 현재 화면에 들어오는 17개 광역시·도 목록 즉시 계산 (많이 축소했을 때)
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

  // 화면에 보이는 시·군·구의 흡연구역/금연구역 개수 비동기 조회 (district_counts 일괄 로드)
  Future<void> _fetchVisibleDistrictCounts() async {
    if (_currentZoom >= kMinAreaZoom) return;
    if (_areaService.cachedRegionCounts.length >= kKoreaDistricts.length) return;

    final loaded = await _areaService.loadAllDistrictCounts();
    if (loaded && mounted && _currentZoom < kMinAreaZoom) {
      setState(() {});
    }
  }

  Future<void> _fetchVisibleAreas() async {
    if (_currentZoom < kMinAreaZoom) return;

    final bounds = _mapController.camera.visibleBounds;
    final minLat = bounds.south;
    final maxLat = bounds.north;
    final minLng = bounds.west;
    final maxLng = bounds.east;

    final results = await Future.wait([
      _areaService.loadSmokingAreasInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        limit: 150,
      ),
      _areaService.loadNonSmokingAreasInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        limit: 150,
      ),
    ]);

    if (mounted && _currentZoom >= kMinAreaZoom) {
      setState(() {
        _smokingAreas = results[0];
        _nonSmokingAreas = results[1];
        if (_currentPosition != null) {
          _evaluateUserLocation(_currentPosition!);
        }
      });
    }
  }

  void _moveToUserLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        17.0,
      );
      _fetchVisibleAreas();
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
      builder: (context) => AreaDetailSheet(
        area: area,
        distanceInMeters: dist,
      ),
    );
  }

  // 필터 및 줌 레벨에 따라 화면에 렌더링할 구역 목록
  List<SmokingArea> get _displayedAreas {
    if (_currentZoom < kMinAreaZoom) return [];

    switch (_currentFilter) {
      case AreaFilterType.smokingOnly:
        return _smokingAreas;
      case AreaFilterType.nonSmokingOnly:
        return _nonSmokingAreas;
      case AreaFilterType.all:
        return [..._smokingAreas, ..._nonSmokingAreas];
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. 메인 지도 (전체화면)
                _buildMapView(userLatLng),

                // 2. 상단 상태 배너 & 필터 칩
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                _mapController.move(
                                  LatLng(targetArea.latitude, targetArea.longitude),
                                  17.5,
                                );
                                _showAreaDetails(targetArea);
                              }
                            },
                          ),
                          const SizedBox(height: 8),

                          // 3. 구역 필터 칩
                          _buildFilterChips(),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. 지도를 축소했을 때 단계별 클러스터 안내 툴팁 뱃지
                if (isClusterMode)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.88),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app, color: Colors.orangeAccent, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            _currentZoom < kMinDistrictZoom
                                ? '시·도 배지를 누르면 시·군·구 단위로 확대됩니다'
                                : '시·군·구 배지를 누르면 상세 구역으로 확대됩니다',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. 방위 정렬(나침반) 버튼
                Positioned(
                  top: 175,
                  right: 16,
                  child: Tooltip(
                    message: '방위 정렬 (북쪽 기준)',
                    child: _buildCompassButton(),
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoomIn',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, currentZoom + 1);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'zoomOut',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, currentZoom - 1);
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'myLocation',
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            onPressed: _moveToUserLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildChip(
            label: '전체',
            filterType: AreaFilterType.all,
            activeColor: const Color(0xFF1E293B),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: '🚬 흡연구역',
            filterType: AreaFilterType.smokingOnly,
            activeColor: const Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: '🚫 금연구역',
            filterType: AreaFilterType.nonSmokingOnly,
            activeColor: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required AreaFilterType filterType,
    required Color activeColor,
  }) {
    final isSelected = _currentFilter == filterType;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _currentFilter = filterType;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.black12,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
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
          rotationThreshold: 5.0,
        ),
        onPositionChanged: _onMapPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.smoke_finder',
          tileProvider: NetworkTileProvider(),
        ),

        // 원형 반경 레이어 (확대 모드일 때만)
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
                      ? const Color(0xFFDC2626).withOpacity(0.40)
                      : const Color(0xFFEF4444).withOpacity(0.18),
                  borderColor: const Color(0xFFDC2626),
                  borderStrokeWidth: isInsideNonSmoking ? 3.0 : 1.5,
                );
              } else {
                return CircleMarker(
                  point: LatLng(area.latitude, area.longitude),
                  radius: area.radius,
                  useRadiusInMeter: true,
                  color: isInsideSmoking
                      ? Colors.green.withOpacity(0.45)
                      : Colors.orange.withOpacity(0.25),
                  borderColor: isInsideSmoking ? Colors.green : Colors.orange,
                  borderStrokeWidth: isInsideSmoking ? 3.0 : 1.5,
                );
              }
            }).toList(),
          ),

        // 마커 레이어 (내 위치 + 3단계 줌 레벨별 배지/마커)
        MarkerLayer(
          rotate: true,
          markers: [
            Marker(
              point: userLatLng,
              width: 50,
              height: 50,
              rotate: true,
              child: _buildUserLocationMarker(),
            ),

            // 1. 많이 축소 시 (zoom < 11.0): 17개 광역시·도 통합 클러스터 배지
            if (isProvinceMode)
              ..._visibleProvinces.map((province) {
                final counts = _areaService.getProvinceCounts(province.sidoKey);
                return Marker(
                  point: LatLng(province.latitude, province.longitude),
                  width: 124,
                  height: 62,
                  rotate: true,
                  child: _buildProvinceClusterBadge(province, counts),
                );
              }),

            // 2. 중간 축소 시 (11.0 <= zoom < 15.0): 시·군·구 클러스터 배지
            if (isDistrictMode)
              ..._visibleRegions.map((region) {
                final counts = _areaService.cachedRegionCounts[region.code];
                return Marker(
                  point: LatLng(region.latitude, region.longitude),
                  width: 118,
                  height: 60,
                  rotate: true,
                  child: _buildDistrictClusterBadge(region, counts),
                );
              }),

            // 3. 확대 시 (zoom >= 15.0): 개별 흡연구역 / 금연구역 마커
            if (!isClusterMode)
              ...displayAreas.map((area) {
                final isCurrent = area.isNonSmoking
                    ? _checkResult?.currentNonSmokingArea?.id == area.id
                    : _checkResult?.currentSmokingArea?.id == area.id;

                final borderColor = area.isNonSmoking
                    ? (isCurrent ? const Color(0xFF991B1B) : const Color(0xFFDC2626))
                    : (isCurrent ? const Color(0xFF2E7D32) : const Color(0xFFD97706));

                final iconAsset = area.isNonSmoking
                    ? 'assets/images/no_smoke.png'
                    : 'assets/images/app_logo.png';

                final fallbackIcon = area.isNonSmoking
                    ? Icons.smoke_free
                    : Icons.smoking_rooms;

                return Marker(
                  point: LatLng(area.latitude, area.longitude),
                  width: 44,
                  height: 44,
                  rotate: true,
                  child: GestureDetector(
                    onTap: () => _showAreaDetails(area),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: borderColor,
                          width: isCurrent ? 3.0 : 2.0,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          iconAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            fallbackIcon,
                            color: borderColor,
                            size: 22,
                          ),
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

  // 광역시·도 묶음(클러스터) 배지 위젯 (줌 11.0 미만)
  Widget _buildProvinceClusterBadge(
    ProvinceRegion province,
    ({int smokingCount, int nonSmokingCount})? counts,
  ) {
    final borderColor = switch (_currentFilter) {
      AreaFilterType.smokingOnly => const Color(0xFFD97706),
      AreaFilterType.nonSmokingOnly => const Color(0xFFDC2626),
      AreaFilterType.all => const Color(0xFF2563EB),
    };

    return GestureDetector(
      onTap: () {
        _mapController.move(
          LatLng(province.latitude, province.longitude),
          province.targetZoom,
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                province.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              if (counts == null)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Colors.white70,
                  ),
                )
              else
                _buildCountRowByValues(
                  smokingCount: counts.smokingCount,
                  nonSmokingCount: counts.nonSmokingCount,
                  isDarkBadge: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 시·군·구 지역 묶음(클러스터) 배지 위젯 (줌 11.0 ~ 15.0 미만)
  Widget _buildDistrictClusterBadge(DistrictRegion region, RegionCounts? counts) {
    final borderColor = switch (_currentFilter) {
      AreaFilterType.smokingOnly => const Color(0xFFD97706),
      AreaFilterType.nonSmokingOnly => const Color(0xFFDC2626),
      AreaFilterType.all => const Color(0xFF1E293B),
    };

    return GestureDetector(
      onTap: () {
        _mapController.move(
          LatLng(region.latitude, region.longitude),
          15.5,
        );
        _fetchVisibleAreas();
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.6),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                region.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              if (counts == null)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Color(0xFF64748B),
                  ),
                )
              else
                _buildCountRowByValues(
                  smokingCount: counts.smokingCount,
                  nonSmokingCount: counts.nonSmokingCount,
                  isDarkBadge: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountRowByValues({
    required int smokingCount,
    required int nonSmokingCount,
    bool isDarkBadge = false,
  }) {
    final smokingColor = isDarkBadge ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final nonSmokingColor = isDarkBadge ? const Color(0xFFF87171) : const Color(0xFFDC2626);

    switch (_currentFilter) {
      case AreaFilterType.smokingOnly:
        return Text(
          '🚬 ${_formatCount(smokingCount)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: smokingColor,
          ),
        );
      case AreaFilterType.nonSmokingOnly:
        return Text(
          '🚫 ${_formatCount(nonSmokingCount)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: nonSmokingColor,
          ),
        );
      case AreaFilterType.all:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🚬${_formatCount(smokingCount)}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: smokingColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                '·',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDarkBadge ? Colors.white54 : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Text(
              '🚫${_formatCount(nonSmokingCount)}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: nonSmokingColor,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _resetRotation,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.black12,
              width: 1,
            ),
          ),
          child: Center(
            child: Transform.rotate(
              angle: _currentRotation * (math.pi / 180.0),
              child: CustomPaint(
                size: const Size(26, 26),
                painter: _CompassNeedlePainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.25),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final halfWidth = size.width * 0.22;

    // 북쪽(N) 바늘
    final northPath = Path()
      ..moveTo(centerX, 2)
      ..lineTo(centerX + halfWidth, centerY)
      ..lineTo(centerX, centerY - 1)
      ..lineTo(centerX - halfWidth, centerY)
      ..close();

    final northPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, northPaint);

    final northRightPath = Path()
      ..moveTo(centerX, 2)
      ..lineTo(centerX + halfWidth, centerY)
      ..lineTo(centerX, centerY)
      ..close();
    final northDarkPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;
    canvas.drawPath(northRightPath, northDarkPaint);

    // 남쪽(S) 바늘
    final southPath = Path()
      ..moveTo(centerX, size.height - 2)
      ..lineTo(centerX + halfWidth, centerY)
      ..lineTo(centerX, centerY + 1)
      ..lineTo(centerX - halfWidth, centerY)
      ..close();

    final southPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;
    canvas.drawPath(southPath, southPaint);

    final southRightPath = Path()
      ..moveTo(centerX, size.height - 2)
      ..lineTo(centerX + halfWidth, centerY)
      ..lineTo(centerX, centerY)
      ..close();
    final southDarkPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.fill;
    canvas.drawPath(southRightPath, southDarkPaint);

    // 중앙 축 핀
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), 2.5, centerPaint);

    final centerBorderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(centerX, centerY), 2.5, centerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
