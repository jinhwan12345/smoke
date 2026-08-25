import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/smoking_area.dart';
import '../services/location_service.dart';
import '../services/smoking_area_service.dart';
import '../widgets/status_banner.dart';
import '../widgets/area_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final SmokingAreaService _areaService = SmokingAreaService();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  List<SmokingArea> _allAreas = [];
  LocationCheckResult? _checkResult;
  bool _isLoading = true;
  bool _showListView = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. 흡연구역 데이터 로드
    final areas = await _areaService.loadSmokingAreas();
    setState(() {
      _allAreas = areas;
    });

    // 2. 위치 권한 및 초기 위치 설정
    await LocationService.requestLocationPermission();
    Position initialPos = await LocationService.getCurrentPosition();
    _handleNewPosition(initialPos);

    // 3. 실시간 위치 스트림 구독
    _positionStream = LocationService.getPositionStream().listen((pos) {
      _handleNewPosition(pos);
    });

    setState(() {
      _isLoading = false;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userPos = _currentPosition;
    final userLatLng = userPos != null
        ? LatLng(userPos.latitude, userPos.longitude)
        : const LatLng(35.90682384, 128.62055516);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smoking_rooms, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text(
              '스모크 존 파인더',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showListView ? Icons.map_outlined : Icons.format_list_bulleted),
            tooltip: _showListView ? '지도 보기' : '주변 목록 보기',
            onPressed: () {
              setState(() {
                _showListView = !_showListView;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. 지도 뷰 or 리스트 뷰
                if (_showListView)
                  _buildNearbyListView()
                else
                  _buildMapView(userLatLng),

                // 2. 상단 흡연구역 여부 실시간 안내 배너
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
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
                  foregroundColor: Colors.black86,
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
                  foregroundColor: Colors.black86,
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

  // 지도 위젯
  Widget _buildMapView(LatLng userLatLng) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userLatLng,
        initialZoom: 17.0,
        minZoom: 5.0,
        maxZoom: 19.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.smoke_finder',
          tileProvider: NetworkTileProvider(),
        ),

        // 흡연구역 유효 반경 Circle 레이어
        CircleLayer(
          circles: _allAreas.map((area) {
            final isCurrentTarget = _checkResult?.currentArea?.id == area.id;
            return CircleMarker(
              point: LatLng(area.latitude, area.longitude),
              radius: area.radius,
              useRadiusInMeter: true,
              color: isCurrentTarget
                  ? Colors.green.withValues(alpha: 0.45)
                  : Colors.orange.withValues(alpha: 0.25),
              borderColor: isCurrentTarget ? Colors.green : Colors.orange,
              borderStrokeWidth: isCurrentTarget ? 3.0 : 1.5,
            );
          }).toList(),
        ),

        // 마커 레이어
        MarkerLayer(
          markers: [
            // 현재 사용자 위치 마커
            Marker(
              point: userLatLng,
              width: 50,
              height: 50,
              child: _buildUserLocationMarker(),
            ),

            // 흡연구역 마커들
            ..._allAreas.map((area) {
              final isCurrent = _checkResult?.currentArea?.id == area.id;
              return Marker(
                point: LatLng(area.latitude, area.longitude),
                width: 44,
                height: 44,
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

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.25),
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

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.only(top: 90),
      child: nearbyList.isEmpty
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
