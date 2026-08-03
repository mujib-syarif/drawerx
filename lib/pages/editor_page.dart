import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/draw_point.dart';
import '../models/draw_stroke.dart';
import '../models/draw_tool.dart';
import '../widgets/drawing_canvas.dart';

class EditorPage extends StatefulWidget {
  final Uint8List image;

  const EditorPage({super.key, required this.image});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final List<DrawStroke> strokes = [];

  final TransformationController transformationController =
      TransformationController();

  DrawStroke? currentStroke;

  Color currentColor = Colors.red;

  double currentWidth = 4;

  DrawTool currentTool = DrawTool.pen;

  bool drawMode = true;

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }

  Offset _convertPoint(Offset localPosition) {
    return transformationController.toScene(localPosition);
  }

  void _startStroke(Offset localPosition) {
    final point = _convertPoint(localPosition);

    currentStroke = DrawStroke(
      points: [DrawPoint(point)],
      color: currentColor,
      width: currentWidth,
      tool: currentTool,
    );

    setState(() {
      strokes.add(currentStroke!);
    });
  }

  void _appendStroke(Offset localPosition) {
    if (currentStroke == null) return;

    final point = _convertPoint(localPosition);

    setState(() {
      currentStroke!.points.add(DrawPoint(point));
    });
  }

  void _finishStroke() {
    currentStroke = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: drawMode ? "Move Mode" : "Draw Mode",
            icon: Icon(drawMode ? Icons.pan_tool : Icons.edit),
            onPressed: () {
              setState(() {
                drawMode = !drawMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {
              if (strokes.isEmpty) return;

              setState(() {
                strokes.removeLast();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                strokes.clear();
              });
            },
          ),
        ],
      ),
      body: InteractiveViewer(
        transformationController: transformationController,
        minScale: 1,
        maxScale: 8,
        boundaryMargin: const EdgeInsets.all(500),
        panEnabled: !drawMode,
        scaleEnabled: !drawMode,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: drawMode
              ? (details) => _startStroke(details.localPosition)
              : null,
          onPanUpdate: drawMode
              ? (details) => _appendStroke(details.localPosition)
              : null,
          onPanEnd: drawMode ? (_) => _finishStroke() : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(widget.image, fit: BoxFit.contain),
              CustomPaint(painter: DrawingCanvas(strokes: strokes)),
            ],
          ),
        ),
      ),
    );
  }
}
