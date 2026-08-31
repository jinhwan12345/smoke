import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
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
  final List<SmokingArea>? preloadedSmokingAreas;
  final Position? initialPosition;

  const MapScreen({
    super.key,
    this.preloadedSmokingAreas,
    this.initialPosition,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SmokingAreaService _areaService = SmokingAreaService();

  // 금연구역 표시 최소 줌 레벨 (5만개 최적화)
  static const double kMinNonSmokingZoom = 15.0;

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;

  List<SmokingArea> _smokingAreas = [];
  List<SmokingArea> _nonSmokingAreas = []; // 현재 화면(BBox) 내 동적 금연구역

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
    // 1. 흡연구역 목록 로드
    if (widget.preloadedSmokingAreas != null && widget.preloadedSmokingAreas!.isNotEmpty) {
      _smokingAreas = widget.preloadedSmokingAreas!;
    } else {
      _smokingAreas = await _areaService.loadSmokingAreas();
    }

    // 2. 위치 권한 및 초기 위치 설정
    await LocationService.requestLocationPermission();
    Position initialPos = widget.initialPosition ?? await LocationService.getCurrentPosition();
    _currentPosition = initialPos;

    // 3. 내 위치 주변 금연구역 1차 로드 (초기 지오펜싱용)
    final initialNearbyNonSmoking = await _areaService.loadNearbyNonSmokingAreas(
      userLat: initialPos.latitude,
      userLng: initialPos.longitude,
    );
    _nonSmokingAreas = initialNearbyNonSmoking;

    _evaluateUserLocation(initialPos);

    setState(() {
      _isLoading = false;
    });

    // 4. 실시간 위치 추적 리스너
    _positionStream = LocationService.getPositionStream().listen((pos) {
      _currentPosition = pos;
      _evaluateUserLocation(pos);
    });

    // 5. 첫 화면 Bounding Box 내 금연구역 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchVisibleNonSmokingAreas();
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

  // 현재 화면 영역(Bounding Box) 내 금연구역 동적 조회 (Debounce 300ms)
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && _rotationAnimationController?.isAnimating == true) {
      _rotationAnimationController?.stop();
    }

    if ((_currentRotation - camera.rotation).abs() > 0.01) {
      setState(() {
        _currentRotation = camera.rotation;
      });
    }

    _currentZoom = camera.zoom;

    // 줌 레벨이 15 이상일 때만 Bounding Box 쿼리 수행
    if (_currentZoom >= kMinNonSmokingZoom) {
      _boundsDebounceTimer?.cancel();
      _boundsDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _fetchVisibleNonSmokingAreas();
      });
    } else {
      if (_nonSmokingAreas.isNotEmpty) {
        setState(() {
          _nonSmokingAreas = [];
        });
      }
    }
  }

  Future<void> _fetchVisibleNonSmokingAreas() async {
    if (_currentZoom < kMinNonSmokingZoom) return;

    final bounds = _mapController.camera.visibleBounds;
    final minLat = bounds.south;
    final maxLat = bounds.north;
    final minLng = bounds.west;
    final maxLng = bounds.east;

    final visibleNonSmoking = await _areaService.loadNonSmokingAreasInBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: 150,
    );

    if (mounted) {
      setState(() {
        _nonSmokingAreas = visibleNonSmoking;
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
      _fetchVisibleNonSmokingAreas();
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
    final showNonSmoking = _currentZoom >= kMinNonSmokingZoom;

    switch (_currentFilter) {
      case AreaFilterType.smokingOnly:
        return _smokingAreas;
      case AreaFilterType.nonSmokingOnly:
        return showNonSmoking ? _nonSmokingAreas : [];
      case AreaFilterType.all:
      default:
        return showNonSmoking
            ? [..._smokingAreas, ..._nonSmokingAreas]
            : _smokingAreas;
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

    final isZoomTooFarForNonSmoking = _currentZoom < kMinNonSmokingZoom;

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

                // 4. 지도를 축소했을 때 금연구역 안내 툴팁 뱃지
                if (isZoomTooFarForNonSmoking && _currentFilter != AreaFilterType.smokingOnly)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.orangeAccent, size: 18),
                          SizedBox(width: 6),
                          Text(
                            '지도를 확대하면 금연구역이 표시됩니다',
                            style: TextStyle(
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
    final showNonSmoking = _currentZoom >= kMinNonSmokingZoom;
    final nonSmokingLabel = showNonSmoking
        ? '🚫 금연구역 (${_nonSmokingAreas.length})'
        : '🚫 금연구역 (확대필요)';

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
            label: '🚬 흡연구역 (${_smokingAreas.length})',
            filterType: AreaFilterType.smokingOnly,
            activeColor: const Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: nonSmokingLabel,
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

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userLatLng,
        initialZoom: 17.0,
        minZoom: 5.0,
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

        // 원형 반경 레이어
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

        // 마커 레이어
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
