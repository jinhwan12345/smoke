import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/sketch_theme.dart';
import 'sketch_widgets.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _downloadedFilePath;
  String? _statusMessage;

  Future<void> _startDownloadAndInstall() async {
    if (_downloadedFilePath != null) {
      await _triggerInstall(_downloadedFilePath!);
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = '최신 APK 파일을 다운로드하는 중...';
    });

    final filePath = await UpdateService.downloadApk(
      widget.updateInfo,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = p;
          });
        }
      },
    );

    if (!mounted) return;

    if (filePath == null) {
      setState(() {
        _isDownloading = false;
        _statusMessage = '다운로드에 실패했어요. 네트워크 상태를 확인해 주세요.';
      });
      return;
    }

    setState(() {
      _isDownloading = false;
      _downloadedFilePath = filePath;
    });

    await _triggerInstall(filePath);
  }

  Future<void> _triggerInstall(String filePath) async {
    final result = await UpdateService.installApk(filePath);
    if (!mounted) return;

    if (result == 'NEEDS_PERMISSION') {
      setState(() {
        _statusMessage = '설정에서 "이 출처의 앱 설치 허용"을 켠 뒤 [설치하기]를 눌러주세요.';
      });
    } else if (result == 'INSTALLED_INTENT_STARTED') {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _statusMessage = '설치 화면을 열지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final percentText = '${(_progress * 100).toStringAsFixed(0)}%';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            SketchBox(
              fillColor: SketchColors.paper,
              borderColor: SketchColors.ink,
              shadowColor: SketchColors.ink,
              strokeWidth: 2.5,
              cornerRadius: 20,
              shadowOffset: const Offset(4, 5),
              seed: 109,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SketchCircle(
                        size: 40,
                        fillColor: SketchColors.blueFill,
                        borderColor: SketchColors.bluePen,
                        strokeWidth: 2.0,
                        shadowOffset: const Offset(1.5, 2),
                        seed: 111,
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: SketchColors.bluePen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: HighlighterText(
                          text: '새 버전 업데이트!',
                          highlightColor: SketchColors.smokeYellow,
                          textAlign: TextAlign.left,
                          style: SketchTextStyles.title(
                            size: 22,
                            color: SketchColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SketchBox(
                    fillColor: SketchColors.paperWarm,
                    borderColor: SketchColors.ink,
                    shadowOffset: Offset.zero,
                    strokeWidth: 1.5,
                    cornerRadius: 10,
                    doubleStroke: false,
                    seed: 115,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        '현재 v${info.currentVersionName}  →  최신 ${info.latestVersionTag}',
                        textAlign: TextAlign.center,
                        style: SketchTextStyles.label(
                          size: 16,
                          color: SketchColors.ink,
                        ),
                      ),
                    ),
                  ),
                  if (_isDownloading) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 10,
                        backgroundColor: SketchColors.notebookLine,
                        color: SketchColors.bluePen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '다운로드 중... $percentText',
                        style: SketchTextStyles.label(
                          size: 14.5,
                          color: SketchColors.bluePen,
                        ),
                      ),
                    ),
                  ],
                  if (_statusMessage != null && !_isDownloading) ...[
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage!,
                      style: SketchTextStyles.body(
                        size: 14.5,
                        color: SketchColors.smokeAmber,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!_isDownloading)
                        SketchButton(
                          fillColor: SketchColors.paper,
                          borderColor: SketchColors.ink,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          seed: 121,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            '나중에',
                            style: SketchTextStyles.label(
                              size: 16,
                              color: SketchColors.inkMuted,
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      SketchButton(
                        fillColor: SketchColors.smokeYellow,
                        borderColor: SketchColors.ink,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        seed: 122,
                        onPressed: _isDownloading ? null : _startDownloadAndInstall,
                        child: Text(
                          _downloadedFilePath != null ? '설치하기' : '지금 업데이트',
                          style: SketchTextStyles.label(
                            size: 16.5,
                            color: SketchColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Positioned(
              top: -10,
              child: MaskingTape(
                width: 80,
                height: 20,
                color: SketchColors.tapeColor,
                angle: 0.03,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
