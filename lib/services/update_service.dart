import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AppUpdateInfo {
  final String currentVersionName;
  final int currentVersionCode;
  final String latestVersionTag;
  final int latestBuildNumber;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String cacheDir;

  const AppUpdateInfo({
    required this.currentVersionName,
    required this.currentVersionCode,
    required this.latestVersionTag,
    required this.latestBuildNumber,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.cacheDir,
  });
}

class UpdateService {
  static const MethodChannel _channel =
      MethodChannel('com.example.smoke_finder/updater');

  static const String _githubReleaseApiUrl =
      'https://api.github.com/repos/jinhwan12345/smoke/releases/latest';

  /// GitHub Releases 최신 버전과 현재 설치된 앱의 버전(versionCode)을 비교합니다.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      // 1. 현재 설치된 앱 버전 정보 조회
      final versionMap = await _channel.invokeMapMethod<String, dynamic>('getAppVersion');
      if (versionMap == null) return null;

      final currentVersionName = versionMap['versionName']?.toString() ?? '1.0.0';
      final currentVersionCode = (versionMap['versionCode'] as num?)?.toInt() ?? 1;
      final cacheDir = versionMap['cacheDir']?.toString() ?? '';
      if (cacheDir.isEmpty) return null;

      // 2. GitHub Releases 최신 릴리즈 조회
      final response = await http.get(
        Uri.parse(_githubReleaseApiUrl),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> data = json.decode(response.body);
      final tagName = data['tag_name']?.toString() ?? '';
      final body = data['body']?.toString().trim() ?? '새로운 버전이 출시되었습니다.';

      // tagName(예: 'v1.0.15')에서 마지막 숫자(빌드 번호 15) 추출
      final latestBuildNumber = _extractBuildNumber(tagName);
      if (latestBuildNumber == null || latestBuildNumber <= currentVersionCode) {
        return null;
      }

      // 3. 릴리즈 에셋(assets)에서 APK 다운로드 URL 찾기
      String? apkUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final asset in assets) {
          final assetName = asset['name']?.toString() ?? '';
          final downloadUrl = asset['browser_download_url']?.toString() ?? '';
          if (assetName.endsWith('.apk') && downloadUrl.isNotEmpty) {
            apkUrl = downloadUrl;
            break;
          }
        }
      }

      if (apkUrl == null) return null;

      return AppUpdateInfo(
        currentVersionName: currentVersionName,
        currentVersionCode: currentVersionCode,
        latestVersionTag: tagName,
        latestBuildNumber: latestBuildNumber,
        releaseNotes: body,
        apkDownloadUrl: apkUrl,
        cacheDir: cacheDir,
      );
    } catch (e) {
      debugPrint('업데이트 확인 중 오류: $e');
      return null;
    }
  }

  /// APK 파일을 앱 캐시 폴더에 다운로드하며 진행률(0.0 ~ 1.0)을 콜백으로 전달합니다.
  static Future<String?> downloadApk(
    AppUpdateInfo info, {
    required void Function(double progress) onProgress,
  }) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(info.apkDownloadUrl));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        return null;
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final filePath = '${info.cacheDir}/smoke_update_${info.latestBuildNumber}.apk';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      return filePath;
    } catch (e) {
      debugPrint('APK 다운로드 오류: $e');
      await sink?.close();
      return null;
    } finally {
      client.close();
    }
  }

  /// 다운로드된 APK 파일 설치 인텐트 실행
  /// 반환값: 'INSTALLED_INTENT_STARTED' | 'NEEDS_PERMISSION' | null
  static Future<String?> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<String>(
        'installApk',
        {'filePath': filePath},
      );
      return res;
    } catch (e) {
      debugPrint('APK 설치 실행 오류: $e');
      return null;
    }
  }

  static int? _extractBuildNumber(String tag) {
    final matches = RegExp(r'(\d+)').allMatches(tag).toList();
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(1) ?? '');
  }
}
