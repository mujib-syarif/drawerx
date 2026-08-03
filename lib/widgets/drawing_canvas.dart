import 'package:flutter/material.dart';

import '../models/draw_stroke.dart';
import '../models/draw_tool.dart';

class DrawingCanvas extends CustomPainter {
  final List<DrawStroke> strokes;

  const DrawingCanvas({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _renderStroke(canvas, stroke);
    }
  }

  void _renderStroke(Canvas canvas, DrawStroke stroke) {
    switch (stroke.tool) {
      case DrawTool.pen:
        _renderPen(canvas, stroke);
        break;

      case DrawTool.arrow:
        _renderArrow(canvas, stroke);
        break;

      case DrawTool.rectangle:
        _renderRectangle(canvas, stroke);
        break;

      case DrawTool.circle:
        _renderCircle(canvas, stroke);
        break;

      case DrawTool.text:
        _renderText(canvas, stroke);
        break;
    }
  }

  Paint _createPaint(DrawStroke stroke) {
    return Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
  }

  // ===========================
  // PEN
  // ===========================

  void _renderPen(Canvas canvas, DrawStroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = _createPaint(stroke);

    final path = Path();

    path.moveTo(stroke.points.first.offset.dx, stroke.points.first.offset.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].offset.dx, stroke.points[i].offset.dy);
    }

    canvas.drawPath(path, paint);
  }

  // ===========================
  // ARROW
  // ===========================

  void _renderArrow(Canvas canvas, DrawStroke stroke) {
    // Sprint Arrow
  }

  // ===========================
  // RECTANGLE
  // ===========================

  void _renderRectangle(Canvas canvas, DrawStroke stroke) {
    // Sprint Rectangle
  }

  // ===========================
  // CIRCLE
  // ===========================

  void _renderCircle(Canvas canvas, DrawStroke stroke) {
    // Sprint Circle
  }

  // ===========================
  // TEXT
  // ===========================

  void _renderText(Canvas canvas, DrawStroke stroke) {
    // Sprint Text
  }

  @override
  bool shouldRepaint(covariant DrawingCanvas oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
