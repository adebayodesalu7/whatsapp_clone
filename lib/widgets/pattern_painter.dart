import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/enums.dart';

class PatternPainter extends CustomPainter {
  final BackgroundPatternType type;
  final Color color;
  final double opacity;

  PatternPainter({
    required this.type,
    required this.color,
    this.opacity = 0.35, // Increased default visibility
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (type == BackgroundPatternType.none) return;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5; // Thicker lines

    final random = math.Random(42);

    // 1. Mandatory Bold Stripes for ALL Titan Wallpapers
    _drawStriped(canvas, size, paint..color = color.withOpacity(opacity * 0.6), angle: 45, spacing: 50);

    // 2. Add specific design elements based on type
    switch (type) {
      case BackgroundPatternType.geometric:
        _drawGeometric(canvas, size, paint, random);
        break;
      case BackgroundPatternType.abstract:
        _drawAbstract(canvas, size, paint, random);
        break;
      case BackgroundPatternType.tech:
        _drawGrid(canvas, size, paint);
        _drawTech(canvas, size, paint, random);
        break;
      case BackgroundPatternType.striped:
        // Already drawn above, adding counter-stripes for "cross-hatch" look
        _drawStriped(canvas, size, paint, angle: -45, spacing: 40);
        break;
      default:
        break;
    }
  }

  void _drawStriped(Canvas canvas, Size size, Paint paint, {double angle = 30, double spacing = 40.0}) {
    final double radian = angle * math.pi / 180;
    final double limit = math.max(size.width, size.height) * 2;
    
    for (double i = -limit; i < limit; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height * math.tan(radian), size.height),
        paint,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    final double spacing = 60.0;
    final gridPaint = Paint()
      ..color = color.withOpacity(opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  void _drawGeometric(Canvas canvas, Size size, Paint paint, math.Random random) {
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < 20; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final radius = 30.0 + random.nextDouble() * 120.0;
      
      if (random.nextBool()) {
        canvas.drawCircle(Offset(startX, startY), radius, paint);
      } else {
        canvas.drawRect(Rect.fromCircle(center: Offset(startX, startY), radius: radius), paint);
      }
    }
  }

  void _drawAbstract(Canvas canvas, Size size, Paint paint, math.Random random) {
    // Floral/Blossom Inspired shapes
    final fillPaint = Paint()
      ..color = color.withOpacity(opacity * 0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final center = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final radius = 50 + random.nextDouble() * 100;
      
      final path = Path();
      for (int j = 0; j < 5; j++) {
        double angle = (j * 72) * math.pi / 180;
        double x = center.dx + math.cos(angle) * radius;
        double y = center.dy + math.sin(angle) * radius;
        if (j == 0) path.moveTo(x, y);
        else path.quadraticBezierTo(center.dx, center.dy, x, y);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
    }
  }

  void _drawTech(Canvas canvas, Size size, Paint paint, math.Random random) {
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    for (int i = 0; i < 25; i++) {
      double x = (random.nextDouble() * size.width / 50).round() * 50;
      double y = (random.nextDouble() * size.height / 50).round() * 50;
      
      final path = Path()..moveTo(x, y);
      for (int j = 0; j < 4; j++) {
        if (random.nextBool()) x += 50 * (random.nextBool() ? 1 : -1);
        else y += 50 * (random.nextBool() ? 1 : -1);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 8, height: 8), paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color || oldDelegate.opacity != opacity;
  }
}
