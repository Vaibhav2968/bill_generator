import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/scan_parser.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  late final AnimationController _lineController;
  bool _isProcessing = false;
  String? _errorMessage;

  static const double _frameSize = 260;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Rect _scanWindow(Size size) {
    final left = (size.width - _frameSize) / 2;
    final top = (size.height - _frameSize) / 2 - 40;
    return Rect.fromLTWH(left, top, _frameSize, _frameSize);
  }

  Future<void> _onSuccess(ScanProductData data) async {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();

    if (!mounted) return;
    Navigator.of(context).pop(data);
  }

  void _onInvalidScan() {
    if (_isProcessing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = 'Could not read Size and Net from barcode';
    });
  }

  void _handleScan(String? rawValue) {
    if (_isProcessing || rawValue == null || rawValue.trim().isEmpty) return;

    final data = ScanParser.parse(rawValue);
    if (data == null) {
      _onInvalidScan();
      return;
    }

    _onSuccess(data);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final window = _scanWindow(size);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Product',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                final torchOn = state.torchState == TorchState.on;
                return Icon(
                  torchOn ? Icons.flash_on : Icons.flash_off,
                  color: torchOn ? Colors.amber : Colors.white,
                );
              },
            ),
            tooltip: 'Torch',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            scanWindow: window,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                _handleScan(barcode.rawValue);
              }
            },
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(scanWindow: window),
              size: size,
            ),
          ),
          Positioned.fromRect(
            rect: window,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _lineController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ScanFramePainter(
                      lineProgress: _lineController.value,
                      showError: _errorMessage != null,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.tealAccent,
                        size: 32,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Align barcode inside the frame',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reads SWG size and net weight automatically',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  _ScannerOverlayPainter({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      );
    final cutout = Path.combine(PathOperation.difference, overlay, hole);

    canvas.drawPath(
      cutout,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}

class _ScanFramePainter extends CustomPainter {
  final double lineProgress;
  final bool showError;

  _ScanFramePainter({
    required this.lineProgress,
    required this.showError,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = showError ? Colors.redAccent : Colors.tealAccent;
    const cornerLen = 28.0;
    const stroke = 4.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void corner(Offset start, Offset horizontalEnd, Offset verticalEnd) {
      canvas.drawLine(start, horizontalEnd, paint);
      canvas.drawLine(start, verticalEnd, paint);
    }

    corner(const Offset(0, 0), const Offset(cornerLen, 0), const Offset(0, cornerLen));
    corner(
      Offset(size.width, 0),
      Offset(size.width - cornerLen, 0),
      Offset(size.width, cornerLen),
    );
    corner(
      Offset(0, size.height),
      Offset(cornerLen, size.height),
      Offset(0, size.height - cornerLen),
    );
    corner(
      Offset(size.width, size.height),
      Offset(size.width - cornerLen, size.height),
      Offset(size.width, size.height - cornerLen),
    );

    final lineY = 12.0 + (size.height - 24.0) * lineProgress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromLTWH(8, lineY, size.width - 16, 2))
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(8, lineY),
      Offset(size.width - 8, lineY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.lineProgress != lineProgress ||
        oldDelegate.showError != showError;
  }
}
