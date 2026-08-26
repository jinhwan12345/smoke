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

class MapScreen extends StatefulWidget {
  final List<SmokingArea>? preloadedAreas;
  final Position? initialPosition;

  const MapScreen({
    super.key,
    this.preloadedAreas,
    this.initialPosition,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SmokingAreaService _areaService = SmokingAreaService();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  List<SmokingArea> _allAreas = [];
  LocationCheckResult? _checkResult;
  bool _isLoading = true;
  bool _showListView = false;
  double _currentRotation = 0.0;

  AnimationController? _rotationAnimationController;
  Animation<double>? _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.preloadedAreas != null && widget.initialPosition != null) {
      _allAreas = widget.preloadedAreas!;
      _handleNewPosition(widget.initialPosition!);
      _isLoading = false;
    } else {
      final areas = await _areaService.loadSmokingAreas();
      setState(() {
        _allAreas = areas;
      });

      await LocationService.requestLocationPermission();
      Position initialPos = await LocationService.getCurrentPosition();
      _handleNewPosition(initialPos);

      setState(() {
        _isLoading = false;
      });
    }

    _positionStream = LocationService.getPositionStream().listen((pos) {
      _handleNewPosition(pos);
    });
  }

  void _handleNewPosition(Position position) {
    setState(() {
      _currentPosition = position;
      _checkResult = LocationService.evaluateLocation(
        userLat: position.latitude,
        userLng: position.longitude,
        areas: _allAreas,
      );
    });
  }

  void _moveToUserLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        17.0,
      );
    }
  }

  void _resetRotation() {
    final startRotation = _mapController.camera.rotation;

    // 회전 각도를 [-180, 180] 범위로 정규화하여 최단 경로로 북쪽(0도) 정렬
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

  @override
  void dispose() {
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

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. 메인 지도 / 목록 뷰 (전체화면)
                if (_showListView)
                  _buildNearbyListView()
                else
                  _buildMapView(userLatLng),

                // 2. 상단 상태 배너 및 목록 보기 버튼 (헤더 대신 깔끔한 오버레이)
                if (!_showListView)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상태 배너
                            Expanded(
                              child: StatusBanner(
                                checkResult: _checkResult,
                                onNavigateToNearest: () {
                                  if (_checkResult?.nearestArea != null) {
                                    final nearest = _checkResult!.nearestArea!;
                                    _mapController.move(
                                      LatLng(nearest.latitude, nearest.longitude),
                                      17.5,
                                    );
                                    _showAreaDetails(nearest);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 목록 보기 토글 버튼
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.format_list_bulleted, color: Colors.white, size: 22),
                                tooltip: '주변 목록 보기',
                                onPressed: () {
                                  setState(() {
                                    _showListView = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 3. 방위 정렬(나침반) 버튼
                if (!_showListView)
                  Positioned(
                    top: 130,
                    right: 16,
                    child: Tooltip(
                      message: '방위 정렬 (북쪽 기준)',
                      child: _buildCompassButton(),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _showListView
          ? null
          : Column(
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

  Widget _buildMapView(LatLng userLatLng) {
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
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && _rotationAnimationController?.isAnimating == true) {
            _rotationAnimationController?.stop();
          }
          if ((_currentRotation - camera.rotation).abs() > 0.01) {
            setState(() {
              _currentRotation = camera.rotation;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.smoke_finder',
          tileProvider: NetworkTileProvider(),
        ),

        CircleLayer(
          circles: _allAreas.map((area) {
            final isCurrentTarget = _checkResult?.currentArea?.id == area.id;
            return CircleMarker(
              point: LatLng(area.latitude, area.longitude),
              radius: area.radius,
              useRadiusInMeter: true,
              color: isCurrentTarget
                  ? Colors.green.withOpacity(0.45)
                  : Colors.orange.withOpacity(0.25),
              borderColor: isCurrentTarget ? Colors.green : Colors.orange,
              borderStrokeWidth: isCurrentTarget ? 3.0 : 1.5,
            );
          }).toList(),
        ),

        // MarkerLayer: rotate: false 로 설정하여 지도 회전 시 흡연구역 아이콘도 지도와 함께 회전
        MarkerLayer(
          rotate: false,
          markers: [
            Marker(
              point: userLatLng,
              width: 50,
              height: 50,
              rotate: false,
              child: _buildUserLocationMarker(),
            ),

            ..._allAreas.map((area) {
              final isCurrent = _checkResult?.currentArea?.id == area.id;
              return Marker(
                point: LatLng(area.latitude, area.longitude),
                width: 44,
                height: 44,
                rotate: false,
                child: GestureDetector(
                  onTap: () => _showAreaDetails(area),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF2E7D32) : const Color(0xFFD97706),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.smoking_rooms,
                      color: Colors.white,
                      size: 24,
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
              angle: -_currentRotation * (math.pi / 180.0),
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

  Widget _buildNearbyListView() {
    if (_currentPosition == null) {
      return const Center(child: Text('현재 위치를 가져오는 중입니다...'));
    }

    final nearbyList = _areaService.getNearbyAreas(
      userLat: _currentPosition!.latitude,
      userLng: _currentPosition!.longitude,
      maxDistanceInMeters: 5000.0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showListView = false;
            });
          },
        ),
        title: const Text(
          '주변 흡연구역 목록',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: nearbyList.isEmpty
          ? const Center(child: Text('반경 5km 이내에 등록된 흡연구역이 없습니다.'))
          : ListView.builder(
              itemCount: nearbyList.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = nearbyList[index];
                final area = item.area;
                final dist = item.distanceInMeters;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: dist <= area.radius
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFEF3C7),
                      child: Icon(
                        Icons.smoking_rooms,
                        color: dist <= area.radius
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD97706),
                      ),
                    ),
                    title: Text(
                      area.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(area.address, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          '${dist.toInt()}m 거리 • ${area.type}',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      setState(() {
                        _showListView = false;
                      });
                      _mapController.move(LatLng(area.latitude, area.longitude), 17.5);
                      _showAreaDetails(area);
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final halfWidth = size.width * 0.22;

    // 북쪽(N) 바늘 (밝은 빨간색)
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

    // 북쪽 바늘 입체 음영 (더 짙은 빨간색)
    final northRightPath = Path()
      ..moveTo(centerX, 2)
      ..lineTo(centerX + halfWidth, centerY)
      ..lineTo(centerX, centerY)
      ..close();
    final northDarkPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;
    canvas.drawPath(northRightPath, northDarkPaint);

    // 남쪽(S) 바늘 (밝은 회색)
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

    // 남쪽 바늘 입체 음영 (더 짙은 회색)
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
