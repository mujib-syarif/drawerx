import 'dart:math';

import 'package:flutter/material.dart';

import '../models/draw_stroke.dart';
import '../models/draw_tool.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawStroke> strokes;

  const DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
  }

  void _drawStroke(Canvas canvas, DrawStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (stroke.tool) {
      case DrawTool.pen:
        _drawPen(canvas, paint, stroke);
        break;

      case DrawTool.arrow:
        _drawArrow(canvas, paint, stroke);
        break;

      case DrawTool.rectangle:
        _drawRectangle(canvas, paint, stroke);
        break;

      case DrawTool.circle:
        _drawCircle(canvas, paint, stroke);
        break;

      case DrawTool.text:
        break;
    }
  }

  void _drawPen(Canvas canvas, Paint paint, DrawStroke stroke) {
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first.offset,
        stroke.width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();

    path.moveTo(stroke.points.first.offset.dx, stroke.points.first.offset.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].offset.dx, stroke.points[i].offset.dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Paint paint, DrawStroke stroke) {
    if (stroke.points.length < 2) {
      return;
    }

    final start = stroke.points.first.offset;
    final end = stroke.points.last.offset;

    canvas.drawLine(start, end, paint);

    final direction = end - start;

    if (direction.distance == 0) {
      return;
    }

    final angle = direction.direction;

    const arrowLength = 18.0;
    const arrowAngle = 0.55;

    final left = Offset(
      end.dx - arrowLength * cos(angle - arrowAngle),
      end.dy - arrowLength * sin(angle - arrowAngle),
    );

    final right = Offset(
      end.dx - arrowLength * cos(angle + arrowAngle),
      end.dy - arrowLength * sin(angle + arrowAngle),
    );

    canvas.drawLine(end, left, paint);
    canvas.drawLine(end, right, paint);
  }

  void _drawRectangle(Canvas canvas, Paint paint, DrawStroke stroke) {
    if (stroke.points.length < 2) {
      return;
    }

    final start = stroke.points.first.offset;
    final end = stroke.points.last.offset;

    canvas.drawRect(Rect.fromPoints(start, end), paint);
  }

  void _drawCircle(Canvas canvas, Paint paint, DrawStroke stroke) {
    if (stroke.points.length < 2) {
      return;
    }

    final start = stroke.points.first.offset;
    final end = stroke.points.last.offset;

    final rect = Rect.fromPoints(start, end);

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
