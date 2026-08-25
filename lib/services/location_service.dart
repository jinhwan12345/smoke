import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/smoking_area.dart';

class LocationCheckResult {
  final bool isInsideSmokingArea;
  final SmokingArea? currentArea; // 내부일 때 해당 흡연구역
  final SmokingArea? nearestArea; // 가장 가까운 흡연구역
  final double distanceToNearest; // 가장 가까운 흡연구역까지 거리 (미터)

  LocationCheckResult({
    required this.isInsideSmokingArea,
    this.currentArea,
    this.nearestArea,
    required this.distanceToNearest,
  });
}

class LocationService {
  // 위치 권한 요청
  static Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 기기의 위치 서비스(GPS)가 꺼져있는 경우
      return false;
    }

    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }

    return status.isGranted;
  }

  // 현재 위치 가져오기 (실패 시 기본 위치 강남역 반환)
  static Future<Position> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // 권한 없거나 GPS 미작동 시 기본 위치(서울 강남역) 반환
      return Position(
        latitude: 37.498095,
        longitude: 127.027610,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  // 위치 추적 스트림
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // 2미터 이동 시마다 갱신
      ),
    );
  }

  // 지오펜싱 계산: 현재 위치가 흡연구역인지 확인
  static LocationCheckResult evaluateLocation({
    required double userLat,
    required double userLng,
    required List<SmokingArea> areas,
  }) {
    if (areas.isEmpty) {
      return LocationCheckResult(
        isInsideSmokingArea: false,
        distanceToNearest: double.infinity,
      );
    }

    SmokingArea? insideArea;
    SmokingArea? nearestArea;
    double minDistance = double.infinity;

    for (var area in areas) {
      // WGS84 구면 삼각법에 의한 거리 계산(미터)
      double distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        area.latitude,
        area.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestArea = area;
      }

      // 지정된 반경 이내에 있으면 흡연구역 내부로 판정
      if (distance <= area.radius) {
        insideArea = area;
      }
    }

    return LocationCheckResult(
      isInsideSmokingArea: insideArea != null,
      currentArea: insideArea,
      nearestArea: nearestArea,
      distanceToNearest: minDistance,
    );
  }
}
