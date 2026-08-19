import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class EditorPage extends StatefulWidget {
  final Uint8List image;

  const EditorPage({super.key, required this.image});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class DrawingStroke {
  final List<Offset> points;
  final double brushSize;

  DrawingStroke({required this.points, required this.brushSize});
}

class _EditorPageState extends State<EditorPage> {
  final TransformationController _transformationController =
      TransformationController();

  final List<DrawingStroke> strokes = [];

  DrawingStroke? currentStroke;

  bool drawMode = true;

  late final Future<ui.Image> _decodedImage;

  double brushSize = 4.0;

  static const List<double> brushSizes = [4, 8, 12, 20];

  static const Color backgroundColor = Color(0xFF070B18);

  static const Color panelColor = Color(0xFF101528);

  static const Color panelDark = Color(0xFF0D1222);

  static const Color activeColor = Color(0xFF24304F);

  static const Color cyanColor = Color(0xFF00D9FF);

  static const Color purpleColor = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();

    _decodedImage = ui
        .instantiateImageCodec(widget.image)
        .then((codec) => codec.getNextFrame())
        .then((frame) => frame.image);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void startStroke(Offset position) {
    final stroke = DrawingStroke(points: [position], brushSize: brushSize);

    setState(() {
      currentStroke = stroke;
      strokes.add(stroke);
    });
  }

  void updateStroke(Offset position) {
    final stroke = currentStroke;

    if (stroke == null) return;

    setState(() {
      stroke.points.add(position);
    });
  }

  void endStroke() {
    currentStroke = null;
  }

  void undo() {
    if (strokes.isEmpty) return;

    setState(() {
      strokes.removeLast();
      currentStroke = null;
    });
  }

  void clearDrawing() {
    if (strokes.isEmpty) return;

    setState(() {
      strokes.clear();
      currentStroke = null;
    });
  }

  TextStyle _font({
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: panelDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,

        appBar: _buildAppBar(),

        body: Column(
          children: [
            Expanded(child: _buildEditorArea()),

            if (drawMode) _buildBrushBar(),

            _buildModeBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,

      centerTitle: false,

      leading: IconButton(
        tooltip: 'Kembali',
        icon: const Icon(Icons.arrow_back_rounded, size: 28),
        color: Colors.white,
        onPressed: () {
          Navigator.pop(context);
        },
      ),

      titleSpacing: 0,

      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),

              boxShadow: [
                BoxShadow(
                  color: cyanColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                ),
              ],
            ),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),

              child: Image.asset(
                'assets/images/drawerx_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [
              Text(
                'DrawerX Editor',
                style: _font(
                  size: 16,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),

              Text(
                drawMode ? 'Coret mode' : 'Zoom mode',
                style: _font(
                  size: 10,
                  weight: FontWeight.w500,
                  color: const Color(0xFF9DA6BA),
                ),
              ),
            ],
          ),
        ],
      ),

      actions: [
        _appBarAction(
          icon: Icons.undo_rounded,
          tooltip: 'Undo',

          enabled: strokes.isNotEmpty,

          onPressed: undo,
        ),

        _appBarAction(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Hapus semua',

          enabled: strokes.isNotEmpty,

          onPressed: clearDrawing,
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  Widget _appBarAction({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),

      child: IconButton(
        tooltip: tooltip,

        onPressed: enabled ? onPressed : null,

        icon: Icon(icon, size: 23),

        color: enabled ? Colors.white : const Color(0xFF454C60),
      ),
    );
  }

  Widget _buildEditorArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<ui.Image>(
          future: _decodedImage,

          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: cyanColor),
              );
            }

            final image = snapshot.data!;

            final imageWidth = image.width.toDouble();

            final imageHeight = image.height.toDouble();

            final viewportWidth = constraints.maxWidth;

            final viewportHeight = constraints.maxHeight;

            final widthRatio = viewportWidth / imageWidth;

            final heightRatio = viewportHeight / imageHeight;

            final scale = widthRatio < heightRatio ? widthRatio : heightRatio;

            final sceneWidth = imageWidth * scale;

            final sceneHeight = imageHeight * scale;

            return Container(
              color: Colors.black,

              child: InteractiveViewer(
                transformationController: _transformationController,

                alignment: Alignment.center,

                minScale: 0.5,
                maxScale: 8.0,

                panEnabled: !drawMode,
                scaleEnabled: !drawMode,

                boundaryMargin: const EdgeInsets.all(200),

                child: Center(
                  child: SizedBox(
                    width: sceneWidth,
                    height: sceneHeight,

                    child: _buildScene(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScene() {
    final scene = Stack(
      fit: StackFit.expand,

      children: [
        Image.memory(widget.image, fit: BoxFit.fill),

        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _DrawingPainter(strokes: strokes)),
          ),
        ),
      ],
    );

    if (!drawMode) {
      return scene;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onPanStart: (details) {
        startStroke(details.localPosition);
      },

      onPanUpdate: (details) {
        updateStroke(details.localPosition);
      },

      onPanEnd: (_) {
        endStroke();
      },

      onPanCancel: () {
        endStroke();
      },

      child: scene,
    );
  }

  Widget _buildBrushBar() {
    return Container(
      height: 68,

      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),

      decoration: const BoxDecoration(
        color: panelDark,

        border: Border(top: BorderSide(color: Colors.white10)),
      ),

      child: Row(
        children: [
          Container(
            width: 38,
            height: 42,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),

              color: Colors.white.withValues(alpha: 0.05),
            ),

            child: const Icon(
              Icons.brush_rounded,
              color: Colors.white70,
              size: 19,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Row(
              children: brushSizes.map((size) {
                final active = brushSize == size;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),

                    child: _brushButton(size: size, active: active),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brushButton({required double size, required bool active}) {
    return Material(
      color: active ? activeColor : const Color(0xFF171C2E),

      borderRadius: BorderRadius.circular(13),

      child: InkWell(
        borderRadius: BorderRadius.circular(13),

        onTap: () {
          setState(() {
            brushSize = size;
          });
        },

        child: SizedBox(
          height: 42,

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Container(
                width: size.clamp(4, 18),

                height: size.clamp(4, 18),

                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 5),

              Text(
                '${size.toInt()}',

                style: _font(
                  size: 11,
                  weight: FontWeight.w700,
                  color: active ? Colors.white : const Color(0xFF9DA6BA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),

      decoration: const BoxDecoration(
        color: panelColor,

        border: Border(top: BorderSide(color: Colors.white10)),
      ),

      child: SafeArea(
        top: false,

        child: Container(
          height: 54,

          decoration: BoxDecoration(
            color: const Color(0xFF0B0F1D),

            borderRadius: BorderRadius.circular(18),

            border: Border.all(color: Colors.white10),
          ),

          padding: const EdgeInsets.all(4),

          child: Row(
            children: [
              Expanded(
                child: _modeButton(
                  icon: Icons.edit_rounded,
                  label: 'Coret',
                  active: drawMode,

                  onTap: () {
                    setState(() {
                      drawMode = true;
                      currentStroke = null;
                    });
                  },
                ),
              ),

              Expanded(
                child: _modeButton(
                  icon: Icons.zoom_in_rounded,
                  label: 'Zoom',
                  active: !drawMode,

                  onTap: () {
                    setState(() {
                      drawMode = false;
                      currentStroke = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? activeColor : Colors.transparent,

      borderRadius: BorderRadius.circular(14),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,

              size: 21,

              color: active ? cyanColor : const Color(0xFF7F879A),
            ),

            const SizedBox(width: 8),

            Text(
              label,

              style: _font(
                size: 13,
                weight: FontWeight.w800,
                color: active ? Colors.white : const Color(0xFF8F97AA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;

  _DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }

      final paint = Paint()
        ..color = Colors.red
        ..strokeWidth = stroke.brushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,

          stroke.brushSize / 2,

          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill,
        );

        continue;
      }

      final path = Path();

      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return true;
  }
}
