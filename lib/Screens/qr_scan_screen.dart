// lib/Screens/qr_scan_screen.dart

import 'package:money_control/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Utils/upi_qr.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

/// Camera viewfinder that scans a UPI QR code and pops with the parsed
/// [UpiQrData] — or [UpiQrData.manual] when the user opts to type the UPI ID.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;
  bool _torchOn = false;
  bool _invalid = false;
  Timer? _invalidTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invalidTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final data = parseUpiQr(raw);
      if (data != null) {
        _handled = true;
        HapticFeedback.mediumImpact();
        unawaited(_controller.stop());
        Navigator.of(context).pop(data);
        return;
      }
    }

    if (!_invalid && mounted) {
      HapticFeedback.vibrate();
      setState(() => _invalid = true);
      _invalidTimer?.cancel();
      _invalidTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _invalid = false);
      });
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      ErrorHandler.showError("Torch is not available on this device.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final winSize = math.min(size.width - 96.w, 280.h);
          final win = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2 - 40.h),
            width: winSize,
            height: winSize,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: win,
                errorBuilder: _errorBuilder,
              ),
              CustomPaint(
                painter: _ScannerOverlayPainter(
                  scrim: Colors.black.withValues(alpha: 0.55),
                  window: win,
                  radius: 24.r,
                ),
              ),
              Positioned(
                left: win.left,
                top: win.top,
                width: win.width,
                height: win.height,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            AppLocalizations.of(context)!.scanQR,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _toggleTorch,
                            icon: Icon(
                              _torchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: _torchOn ? AppColors.secondary : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: win.top - 20.h),
                    if (_invalid)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.upiQRCodeTryAgain,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 24.w,
                        right: 24.w,
                        bottom: 20.h,
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.alignUPIQRCodeWithin,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16.h),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop(UpiQrData.manual);
                            },
                            child: GlassContainer(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 14.h,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.keyboard_alt_outlined,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.primary,
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    AppLocalizations.of(context)!.typeUPIIDInstead,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _errorBuilder(BuildContext context, MobileScannerException error) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPermission ? Icons.lock_outline : Icons.no_photography_outlined,
            color: Colors.white38,
            size: 40.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            isPermission
                ? _permissionCopy()
                : "The camera is unavailable on this device.\nMake sure no other app is using it.",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          if (isPermission) ...[
            ElevatedButton.icon(
              onPressed: _grantAndRetry,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(AppLocalizations.of(context)!.grantPermission),
            ),
            SizedBox(height: 8.h),
          ],
          OutlinedButton(
            onPressed: isPermission
                ? () => openAppSettings()
                : () => Navigator.of(context).pop(),
            child: Text(isPermission ? "Open Settings" : "Close"),
          ),
        ],
      ),
    );
  }

  String _permissionCopy() {
    if (kIsWeb) {
      return "Camera access is required to scan a UPI QR code.\nAllow it in your browser settings.";
    }
    if (Platform.isIOS) {
      return "Camera permission is required to scan a UPI QR code.\nEnable it in Settings > Privacy > Camera.";
    }
    return "Camera permission is required to scan a UPI QR code.\nAllow it when the system prompt appears.";
  }

  Future<void> _grantAndRetry() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      await _controller.start();
    } else {
      ErrorHandler.showError("Camera permission is still denied.");
    }
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color scrim;
  final Rect window;
  final double radius;

  const _ScannerOverlayPainter({
    required this.scrim,
    required this.window,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(window, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = scrim);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) =>
      oldDelegate.scrim != scrim ||
      oldDelegate.window != window ||
      oldDelegate.radius != radius;
}
