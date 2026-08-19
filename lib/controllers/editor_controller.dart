import 'package:flutter/material.dart';

import '../models/draw_point.dart';
import '../models/draw_stroke.dart';
import '../models/draw_tool.dart';

class EditorController extends ChangeNotifier {
  final List<DrawStroke> _strokes = [];

  DrawStroke? _currentStroke;

  Color _color = Colors.red;
  double _width = 4.0;
  DrawTool _tool = DrawTool.pen;

  List<DrawStroke> get strokes => List.unmodifiable(_strokes);

  Color get color => _color;

  double get width => _width;

  DrawTool get tool => _tool;

  bool get canUndo => _strokes.isNotEmpty;

  void setColor(Color color) {
    _color = color;
    notifyListeners();
  }

  void setWidth(double width) {
    _width = width;
    notifyListeners();
  }

  void setTool(DrawTool tool) {
    _tool = tool;
    notifyListeners();
  }

  void startStroke(Offset position) {
    if (_tool != DrawTool.pen) {
      return;
    }

    final stroke = DrawStroke(
      points: [DrawPoint(position)],
      color: _color,
      width: _width,
      tool: _tool,
    );

    _currentStroke = stroke;
    _strokes.add(stroke);

    notifyListeners();
  }

  void updateStroke(Offset position) {
    if (_currentStroke == null) {
      return;
    }

    _currentStroke!.points.add(DrawPoint(position));

    notifyListeners();
  }

  void endStroke() {
    _currentStroke = null;
  }

  void undo() {
    if (_strokes.isEmpty) {
      return;
    }

    _strokes.removeLast();

    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _currentStroke = null;

    notifyListeners();
  }
}
