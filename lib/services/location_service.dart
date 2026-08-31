import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/smoking_area.dart';

class LocationCheckResult {
  final bool isInsideSmokingArea;
  final bool isInsideNonSmokingArea;
  final SmokingArea? currentSmokingArea;
  final SmokingArea? currentNonSmokingArea;
  final SmokingArea? nearestSmokingArea;
  final SmokingArea? nearestNonSmokingArea;
  final double distanceToNearestSmoking;
  final double distanceToNearestNonSmoking;

  LocationCheckResult({
    required this.isInsideSmokingArea,
    this.isInsideNonSmokingArea = false,
    this.currentSmokingArea,
    this.currentNonSmokingArea,
    this.nearestSmokingArea,
    this.nearestNonSmokingArea,
    required this.distanceToNearestSmoking,
    this.distanceToNearestNonSmoking = double.infinity,
  });

  // 이전 코드 호환성용 getter
  SmokingArea? get currentArea => currentSmokingArea ?? currentNonSmokingArea;
  SmokingArea? get nearestArea => nearestSmokingArea ?? nearestNonSmokingArea;
  double get distanceToNearest => distanceToNearestSmoking;
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

  // 지오펜싱 계산: 현재 위치가 흡연구역 또는 금연구역인지 판정
  static LocationCheckResult evaluateLocation({
    required double userLat,
    required double userLng,
    required List<SmokingArea> areas,
  }) {
    if (areas.isEmpty) {
      return LocationCheckResult(
        isInsideSmokingArea: false,
        isInsideNonSmokingArea: false,
        distanceToNearestSmoking: double.infinity,
        distanceToNearestNonSmoking: double.infinity,
      );
    }

    SmokingArea? insideSmokingArea;
    SmokingArea? insideNonSmokingArea;

    SmokingArea? nearestSmoking;
    SmokingArea? nearestNonSmoking;

    double minDistanceSmoking = double.infinity;
    double minDistanceNonSmoking = double.infinity;

    for (var area in areas) {
      // WGS84 구면 삼각법에 의한 거리 계산(미터)
      double distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        area.latitude,
        area.longitude,
      );

      if (area.isNonSmoking) {
        // 금연구역 처리
        if (distance < minDistanceNonSmoking) {
          minDistanceNonSmoking = distance;
          nearestNonSmoking = area;
        }
        if (distance <= area.radius) {
          insideNonSmokingArea = area;
        }
      } else {
        // 흡연구역 처리
        if (distance < minDistanceSmoking) {
          minDistanceSmoking = distance;
          nearestSmoking = area;
        }
        if (distance <= area.radius) {
          insideSmokingArea = area;
        }
      }
    }

    return LocationCheckResult(
      isInsideSmokingArea: insideSmokingArea != null,
      isInsideNonSmokingArea: insideNonSmokingArea != null,
      currentSmokingArea: insideSmokingArea,
      currentNonSmokingArea: insideNonSmokingArea,
      nearestSmokingArea: nearestSmoking,
      nearestNonSmokingArea: nearestNonSmoking,
      distanceToNearestSmoking: minDistanceSmoking,
      distanceToNearestNonSmoking: minDistanceNonSmoking,
    );
  }
}
