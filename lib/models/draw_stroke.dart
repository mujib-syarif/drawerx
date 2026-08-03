import 'package:flutter/material.dart';

import 'draw_point.dart';
import 'draw_tool.dart';

class DrawStroke {
  /// Tool yang digunakan
  DrawTool tool;

  /// Warna object
  Color color;

  /// Ketebalan garis
  double width;

  /// Titik-titik object.
  ///
  /// Pen      -> banyak titik
  /// Arrow    -> 2 titik
  /// Rectangle-> 2 titik
  /// Circle   -> 2 titik
  /// Text     -> 1 titik
  List<DrawPoint> points;

  /// Optional text
  String? text;

  /// Optional id
  final String id;

  /// Visibility
  bool visible;

  DrawStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
    this.text,
    this.visible = true,
    String? id,
  }) : id = id ?? UniqueKey().toString();

  DrawPoint? get firstPoint {
    if (points.isEmpty) return null;
    return points.first;
  }

  DrawPoint? get lastPoint {
    if (points.isEmpty) return null;
    return points.last;
  }

  bool get hasEnoughPoints {
    switch (tool) {
      case DrawTool.pen:
        return points.length >= 2;

      case DrawTool.arrow:
      case DrawTool.rectangle:
      case DrawTool.circle:
        return points.length >= 2;

      case DrawTool.text:
        return points.isNotEmpty;
    }
  }

  DrawStroke copyWith({
    List<DrawPoint>? points,
    Color? color,
    double? width,
    DrawTool? tool,
    String? text,
    bool? visible,
  }) {
    return DrawStroke(
      id: id,
      points: points ?? List.from(this.points),
      color: color ?? this.color,
      width: width ?? this.width,
      tool: tool ?? this.tool,
      text: text ?? this.text,
      visible: visible ?? this.visible,
    );
  }
}
