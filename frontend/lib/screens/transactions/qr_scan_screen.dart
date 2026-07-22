// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : qr_scan_screen.dart
// Description     : Camera-based QR scanner for the TOTP handshake, with a manual-entry fallback.
// First Written on: Monday,06-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../widgets/empty_state.dart';

/// Camera QR scanner. Pops with the raw scanned string (the JSON payload) on
/// the first successful read. The caller extracts the code and verifies it.
///
/// Note: camera scanning is unreliable on Flutter web — the "Enter code
/// manually" fallback on the previous screen covers that case.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  /// Sentinel value popped when the user opts into manual entry from the
  /// camera-permission-denied fallback, so the caller can reopen its own
  /// manual-entry dialog instead of treating this as a real scan result.
  static const manualEntryRequested = '__unilink_manual_entry_requested__';

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That code doesn\'t look right — try again.')),
      );
      return;
    }
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan code')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              // mobile_scanner's permission/error behavior differs across
              // platforms (especially web) — treat any error defensively as
              // a reason to fall back rather than assuming a specific cause.
              final isPermissionDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
              return ColoredBox(
                color: Colors.black,
                child: EmptyState(
                  icon: Icons.no_photography_outlined,
                  title: isPermissionDenied ? 'Camera access denied' : 'Camera unavailable',
                  message: isPermissionDenied
                      ? 'Allow camera access in your device settings, or enter the code manually instead.'
                      : 'Something went wrong starting the camera. You can enter the code manually instead.',
                  actionLabel: 'Enter code manually',
                  onAction: () => Navigator.of(context).pop(QrScanScreen.manualEntryRequested),
                ),
              );
            },
          ),
          // Corner-bracket viewfinder.
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              children: [
                _viewfinderCorner(scheme.primary, top: true, left: true),
                _viewfinderCorner(scheme.primary, top: true, left: false),
                _viewfinderCorner(scheme.primary, top: false, left: true),
                _viewfinderCorner(scheme.primary, top: false, left: false),
              ],
            ),
          ),
          const Positioned(
            bottom: 40,
            child: Text(
              'Point at the other person\'s QR code',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewfinderCorner(Color color, {required bool top, required bool left}) {
    const length = 32.0;
    const thickness = 4.0;
    final side = BorderSide(color: color, width: thickness);
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: length,
        height: length,
        decoration: BoxDecoration(
          border: Border(
            top: top ? side : BorderSide.none,
            bottom: top ? BorderSide.none : side,
            left: left ? side : BorderSide.none,
            right: left ? BorderSide.none : side,
          ),
        ),
      ),
    );
  }
}
