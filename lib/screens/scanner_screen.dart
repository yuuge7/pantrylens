import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../pantry_actions.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';

/// Full-screen camera scanner. Pops with a [ScanOutcome] after one item, or
/// stays open when "Keep scanning" is on.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  static const Duration _repeatScanDelay = Duration(milliseconds: 2500);

  final MobileScannerController _controller = MobileScannerController();

  bool _isHandlingBarcode = false;
  bool _isEnteringBarcode = false;
  String? _lastBarcode;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastResult;
  int _addedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A caller-provided controller is not paused by MobileScanner itself.
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    unawaited(_controller.dispose());
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandlingBarcode || _isEnteringBarcode) return;

    String? barcode;
    for (final result in capture.barcodes) {
      final value = result.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        barcode = value;
        break;
      }
    }
    if (barcode == null) return;

    // The camera reports the same code many times a second; in keep-scanning
    // mode, wait before counting the same product again.
    final sinceLastScan = DateTime.now().difference(_lastScanAt);
    if (barcode == _lastBarcode && sinceLastScan < _repeatScanDelay) return;

    unawaited(_addBarcode(barcode));
  }

  Future<void> _addBarcode(String barcode) async {
    final pantry = context.read<PantryProvider>();
    final settings = context.read<SettingsProvider>();
    setState(() => _isHandlingBarcode = true);

    try {
      final outcome = await pantry.onBarcodeScanned(
        barcode,
        shelfLifeDays: settings.shelfLifeDays,
        lookUpProduct: settings.lookUpProducts,
      );
      if (!mounted) return;
      if (outcome == null) {
        setState(() => _isHandlingBarcode = false);
        return;
      }

      if (settings.vibrateOnScan) unawaited(HapticFeedback.mediumImpact());
      _lastBarcode = barcode;
      _lastScanAt = DateTime.now();

      if (settings.keepScanning) {
        setState(() {
          _isHandlingBarcode = false;
          _addedCount++;
          _lastResult = describeScanOutcome(outcome);
        });
      } else {
        Navigator.of(context).pop(outcome);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isHandlingBarcode = false);
      showMessage(context, 'Barcode $barcode was not saved. Scan it again.');
    }
  }

  Future<void> _enterBarcode() async {
    setState(() => _isEnteringBarcode = true);
    final barcode = await showBarcodeDialog(context);
    if (!mounted) return;
    setState(() => _isEnteringBarcode = false);
    if (barcode != null) await _addBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final keepScanning = context.select<SettingsProvider, bool>(
      (settings) => settings.keepScanning,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('Scan barcode'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final canSwitch =
                  state.isRunning && (state.availableCameras ?? 2) > 1;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.torchState != TorchState.unavailable &&
                      state.isRunning)
                    IconButton(
                      tooltip:
                          state.torchState == TorchState.on
                              ? 'Turn off flashlight'
                              : 'Turn on flashlight',
                      onPressed: _controller.toggleTorch,
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                      ),
                    ),
                  if (canSwitch)
                    IconButton(
                      tooltip: 'Switch camera',
                      onPressed: () => _controller.switchCamera(),
                      icon: const Icon(Icons.cameraswitch_outlined),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder:
                (context, state, _) =>
                    state.error == null
                        ? const IgnorePointer(child: _ScanFrame())
                        : const SizedBox.shrink(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: _ScannerPanel(
                status:
                    _isHandlingBarcode
                        ? 'Adding item to your pantry…'
                        : _lastResult ??
                            'Point the camera at a product barcode',
                isBusy: _isHandlingBarcode,
                addedCount: keepScanning ? _addedCount : null,
                onEnterBarcode: _isHandlingBarcode ? null : _enterBarcode,
                onDone:
                    keepScanning && _addedCount > 0
                        ? () => Navigator.of(context).pop()
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Corner brackets that echo the launcher icon's viewfinder.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.2),
      child: SizedBox(
        width: 280,
        height: 180,
        child: CustomPaint(painter: _CornerPainter(color: AppTheme.leaf)),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 36.0;
    const radius = 14.0;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;

    for (final (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
      final x = dx * size.width;
      final y = dy * size.height;
      final sx = dx == 0 ? 1.0 : -1.0;
      final sy = dy == 0 ? 1.0 : -1.0;
      final path =
          Path()
            ..moveTo(x, y + sy * arm)
            ..lineTo(x, y + sy * radius)
            ..quadraticBezierTo(x, y, x + sx * radius, y)
            ..lineTo(x + sx * arm, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => oldDelegate.color != color;
}

class _ScannerPanel extends StatelessWidget {
  const _ScannerPanel({
    required this.status,
    required this.isBusy,
    required this.onEnterBarcode,
    this.addedCount,
    this.onDone,
  });

  final String status;
  final bool isBusy;
  final int? addedCount;
  final VoidCallback? onEnterBarcode;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addedCount = this.addedCount;
    final onDone = this.onDone;

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xE60D1A15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isBusy) ...[
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.leaf,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (addedCount != null && addedCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              addedCount == 1
                  ? '1 scan this session'
                  : '$addedCount scans this session',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  onPressed: onEnterBarcode,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Enter barcode'),
                ),
              ),
              if (onDone != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.leaf,
                      foregroundColor: AppTheme.forest,
                    ),
                    onPressed: onDone,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, message) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
        'Camera access is off',
        'Allow camera access for PantryLens in your device settings, or '
            'type the barcode instead.',
      ),
      MobileScannerErrorCode.unsupported => (
        'No camera scanning here',
        'This device can’t scan barcodes. Type the barcode instead.',
      ),
      _ => (
        'Camera unavailable',
        'The camera could not start. Close other camera apps and try again, '
            'or type the barcode instead.',
      ),
    };

    return ColoredBox(
      color: AppTheme.canopy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 160),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: AppTheme.leaf,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
