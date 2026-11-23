import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/rescue_request.dart';

/// 擬似位置情報マップ（mamo の .fake-map 背景パターンとピン配置を再現）
class FakeMapView extends StatelessWidget {
  const FakeMapView({
    super.key,
    required this.requests,
    required this.onPinTap,
    this.height,
  });

  final List<RescueRequest> requests;
  final ValueChanged<String> onPinTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: const Color(0xFFE9EDF0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final actualHeight = constraints.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FakeMapBackgroundPainter(),
                    ),
                  ),
                  for (final r in requests)
                    Positioned(
                      left: (width * (r.latPercent / 100)).clamp(
                        8.0,
                        math.max(8.0, width - 36),
                      ),
                      top: (actualHeight * (r.topPercent / 100)).clamp(
                        8.0,
                        math.max(8.0, actualHeight - 36),
                      ),
                      child: _MapPin(
                        request: r,
                        onTap: () => onPinTap(r.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.request,
    required this.onTap,
  });

  final RescueRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${request.name}：${request.status.label}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Transform.rotate(
            angle: -math.pi / 4,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: request.pinColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x45000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeMapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. 25deg 青灰色の道路風ライン (tile: 190x150)
    _drawRepeatingStripe(
      canvas: canvas,
      size: size,
      tileW: 190,
      tileH: 150,
      angleDeg: 25,
      color: const Color(0xFFB8C5CE),
      strokeWidth: 4,
    );

    // 2. 120deg 緑系エリア帯 (tile: 240x180)
    _drawRepeatingStripe(
      canvas: canvas,
      size: size,
      tileW: 240,
      tileH: 180,
      angleDeg: 120,
      color: const Color(0xFFC7D0B6),
      strokeWidth: 22,
    );

    // 3. 5deg ベージュ系道路風ライン (tile: 300x210)
    _drawRepeatingStripe(
      canvas: canvas,
      size: size,
      tileW: 300,
      tileH: 210,
      angleDeg: 5,
      color: const Color(0xFFD5C9B8),
      strokeWidth: 5,
    );
  }

  void _drawRepeatingStripe({
    required Canvas canvas,
    required Size size,
    required double tileW,
    required double tileH,
    required double angleDeg,
    required Color color,
    required double strokeWidth,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rad = angleDeg * math.pi / 180;
    final dx = math.cos(rad);
    final dy = math.sin(rad);
    final length = math.max(tileW, tileH) * 1.6;

    for (double y = -tileH; y < size.height + tileH; y += tileH) {
      for (double x = -tileW; x < size.width + tileW; x += tileW) {
        final cx = x + tileW / 2;
        final cy = y + tileH / 2;
        canvas.drawLine(
          Offset(cx - dx * length / 2, cy - dy * length / 2),
          Offset(cx + dx * length / 2, cy + dy * length / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
