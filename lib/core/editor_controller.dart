import 'package:flutter/material.dart';

import '../models/draw_stroke.dart';
import '../models/draw_tool.dart';

class EditorController extends ChangeNotifier {
  final TransformationController transformationController =
      TransformationController();

  final List<DrawStroke> strokes = [];

  DrawTool tool = DrawTool.pen;

  Color color = Colors.red;

  double strokeWidth = 4;

  bool drawMode = true;

  bool get moveMode => !drawMode;

  void toggleMode() {
    drawMode = !drawMode;
    notifyListeners();
  }

  void setTool(DrawTool value) {
    tool = value;
    notifyListeners();
  }

  void setColor(Color value) {
    color = value;
    notifyListeners();
  }

  void setStrokeWidth(double value) {
    strokeWidth = value;
    notifyListeners();
  }

  void addStroke(DrawStroke stroke) {
    strokes.add(stroke);
    notifyListeners();
  }

  void undo() {
    if (strokes.isEmpty) return;

    strokes.removeLast();
    notifyListeners();
  }

  void clear() {
    strokes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }
}
