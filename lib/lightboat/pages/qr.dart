import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

/// Dark modules on a white tile in both themes: wallet scanners need it.
class LbQrCode extends StatelessWidget {
  final String data;
  final double size;

  const LbQrCode({super.key, required this.data, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(data)));
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: AppShape.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CustomPaint(size: Size.square(size), painter: _QrPainter(image)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrImage image;

  _QrPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final cell = size.width / count;
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(col * cell, row * cell, cell + 0.5, cell + 0.5),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
