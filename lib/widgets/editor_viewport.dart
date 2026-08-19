import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../painters/drawing_painter.dart';

enum EditorMode { draw, zoom }

class EditorViewport extends StatefulWidget {
  final ImageProvider image;
  final EditorController controller;
  final EditorMode mode;

  const EditorViewport({
    super.key,
    required this.image,
    required this.controller,
    required this.mode,
  });

  @override
  State<EditorViewport> createState() => _EditorViewportState();
}

class _EditorViewportState extends State<EditorViewport> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: _transformationController,

          // Mode ZOOM:
          // 1 jari = pan
          // 2 jari = zoom
          panEnabled: widget.mode == EditorMode.zoom,
          scaleEnabled: widget.mode == EditorMode.zoom,

          minScale: 0.5,
          maxScale: 8.0,
          boundaryMargin: const EdgeInsets.all(100),

          constrained: true,

          child: _buildCanvas(constraints),
        );
      },
    );
  }

  Widget _buildCanvas(BoxConstraints constraints) {
    return FutureBuilder<ImageInfo>(
      future: _resolveImage(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 300,
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final info = snapshot.data!;

        final imageWidth = info.image.width.toDouble();
        final imageHeight = info.image.height.toDouble();

        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        final imageRatio = imageWidth / imageHeight;
        final screenRatio = availableWidth / availableHeight;

        late double displayWidth;
        late double displayHeight;

        if (imageRatio > screenRatio) {
          displayWidth = availableWidth;
          displayHeight = availableWidth / imageRatio;
        } else {
          displayHeight = availableHeight;
          displayWidth = availableHeight * imageRatio;
        }

        return Center(
          child: SizedBox(
            width: displayWidth,
            height: displayHeight,

            child: Stack(
              fit: StackFit.expand,

              children: [
                Image(image: widget.image, fit: BoxFit.contain),

                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: widget.controller,

                    builder: (context, _) {
                      return CustomPaint(
                        painter: DrawingPainter(
                          strokes: widget.controller.strokes,
                        ),
                      );
                    },
                  ),
                ),

                if (widget.mode == EditorMode.draw)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,

                    onPanStart: (details) {
                      widget.controller.startStroke(details.localPosition);
                    },

                    onPanUpdate: (details) {
                      widget.controller.updateStroke(details.localPosition);
                    },

                    onPanEnd: (_) {
                      widget.controller.endStroke();
                    },

                    child: const SizedBox.expand(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<ImageInfo> _resolveImage() {
    final completer = Completer<ImageInfo>();

    final stream = widget.image.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);

        if (!completer.isCompleted) {
          completer.complete(info);
        }
      },

      onError: (Object exception, StackTrace? stackTrace) {
        stream.removeListener(listener);

        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
      },
    );

    stream.addListener(listener);

    return completer.future;
  }
}
