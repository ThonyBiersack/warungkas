import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_service.dart';
import 'product_result_screen.dart';

class ScannerScreen extends StatefulWidget {
  final bool returnBarcode;
  const ScannerScreen({super.key, this.returnBarcode = false});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      if (widget.returnBarcode) {
        Navigator.pop(context, rawValue);
        return;
      }
      final product = await DatabaseService.instance.getProductByBarcode(rawValue);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductResultScreen(barcode: rawValue, product: product)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan gagal: $e', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),
          // Dark overlay with cutout
          CustomPaint(painter: _OverlayPainter(), child: const SizedBox.expand()),
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _iconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                  const Spacer(),
                  Text('Scan Barcode', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
                  const Spacer(),
                  _iconBtn(
                    _torchOn ? Icons.flash_on : Icons.flash_off,
                    () { _ctrl.toggleTorch(); setState(() => _torchOn = !_torchOn); },
                    active: _torchOn,
                  ),
                ],
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 52),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                ),
              ),
              child: Column(
                children: [
                  Text('Arahkan kamera ke barcode produk', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('Sistem akan otomatis mendeteksi', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          // Loading
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF00A67E))),
            ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00A67E).withValues(alpha: 0.25) : Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: const Color(0xFF00A67E)) : null,
        ),
        child: Icon(icon, color: active ? const Color(0xFF00A67E) : Colors.white, size: 20),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6)..style = PaintingStyle.fill;
    const w = 280.0;
    const h = 180.0;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2 - 40), width: w, height: h);
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
        ..fillType = PathFillType.evenOdd,
      paint,
    );
    // Corner brackets
    final cp = Paint()..color = const Color(0xFF00A67E)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const cl = 28.0;
    const cr = 16.0;
    void drawCorners(Offset tl) {
      // TL
      canvas.drawLine(tl.translate(cr, 0), tl.translate(cl, 0), cp);
      canvas.drawLine(tl.translate(0, cr), tl.translate(0, cl), cp);
      // TR
      final tr = Offset(rect.right, tl.dy);
      canvas.drawLine(tr.translate(-cl, 0), tr.translate(-cr, 0), cp);
      canvas.drawLine(tr.translate(0, cr), tr.translate(0, cl), cp);
      // BL
      final bl = Offset(tl.dx, rect.bottom);
      canvas.drawLine(bl.translate(cr, 0), bl.translate(cl, 0), cp);
      canvas.drawLine(bl.translate(0, -cl), bl.translate(0, -cr), cp);
      // BR
      final br = Offset(rect.right, rect.bottom);
      canvas.drawLine(br.translate(-cl, 0), br.translate(-cr, 0), cp);
      canvas.drawLine(br.translate(0, -cl), br.translate(0, -cr), cp);
    }
    drawCorners(rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
