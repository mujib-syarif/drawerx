import 'dart:math' as math;
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

  DrawingStroke copy() =>
      DrawingStroke(points: List<Offset>.from(points), brushSize: brushSize);
}

class HeroObject {
  final String id;
  final String name;
  final String assetPath;
  Offset position;
  double scale;
  double rotation;

  HeroObject({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  HeroObject copy() => HeroObject(
    id: id,
    name: name,
    assetPath: assetPath,
    position: position,
    scale: scale,
    rotation: rotation,
  );
}

class _EditorSnapshot {
  final List<DrawingStroke> strokes;
  final List<HeroObject> heroes;
  final String? selectedHeroId;

  _EditorSnapshot({
    required this.strokes,
    required this.heroes,
    required this.selectedHeroId,
  });

  factory _EditorSnapshot.fromState({
    required List<DrawingStroke> strokes,
    required List<HeroObject> heroes,
    required String? selectedHeroId,
  }) {
    return _EditorSnapshot(
      strokes: strokes.map((e) => e.copy()).toList(),
      heroes: heroes.map((e) => e.copy()).toList(),
      selectedHeroId: selectedHeroId,
    );
  }
}

class _HeroDefinition {
  final String name;
  final String assetPath;

  const _HeroDefinition(this.name, this.assetPath);
}

class _EditorPageState extends State<EditorPage> {
  late final Future<ui.Image> _decodedImage;

  final List<DrawingStroke> strokes = [];
  final List<HeroObject> heroes = [];

  DrawingStroke? currentStroke;
  String? selectedHeroId;

  Matrix4 _transform = Matrix4.identity();
  double _scale = 1.0;
  Size _canvasSize = Size.zero;

  final Map<int, Offset> _pointers = {};
  Offset? _lastFocalPoint;
  double? _lastDistance;
  bool _wasMultiTouch = false;

  HeroObject? _movingHero;
  Offset? _heroDragOffset;

  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];
  int _heroCounter = 0;

  double brushSize = 8.0;

  static const List<double> brushSizes = [4, 8, 12, 20];

  static const List<_HeroDefinition> heroDefinitions = [
    _HeroDefinition(
      'Barbarian King',
      'assets/images/heroes/barbarian_king.png',
    ),
    _HeroDefinition('Archer Queen', 'assets/images/heroes/archer_queen.png'),
    _HeroDefinition('Minion Prince', 'assets/images/heroes/minion_prince.png'),
    _HeroDefinition('Grand Warden', 'assets/images/heroes/grand_warden.png'),
    _HeroDefinition(
      'Royal Champion',
      'assets/images/heroes/royal_champion.png',
    ),
    _HeroDefinition('Dragon Duke', 'assets/images/heroes/dragon_duke.png'),
  ];

  static const Color backgroundColor = Color(0xFF070B18);
  static const Color panelDark = Color(0xFF0D1222);
  static const Color activeColor = Color(0xFF24304F);
  static const Color cyanColor = Color(0xFF00D9FF);

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
    super.dispose();
  }

  TextStyle _font({double? size, FontWeight? weight, Color? color}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  HeroObject? get _selectedHero {
    if (selectedHeroId == null) return null;
    for (final hero in heroes) {
      if (hero.id == selectedHeroId) return hero;
    }
    return null;
  }

  void _saveHistory() {
    _undoStack.add(
      _EditorSnapshot.fromState(
        strokes: strokes,
        heroes: heroes,
        selectedHeroId: selectedHeroId,
      ),
    );
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _restoreSnapshot(_EditorSnapshot snapshot) {
    strokes
      ..clear()
      ..addAll(snapshot.strokes.map((e) => e.copy()));
    heroes
      ..clear()
      ..addAll(snapshot.heroes.map((e) => e.copy()));
    selectedHeroId = snapshot.selectedHeroId;
    currentStroke = null;
    _movingHero = null;
    _heroDragOffset = null;
  }

  void _undo() {
    if (_undoStack.isEmpty) return;

    _redoStack.add(
      _EditorSnapshot.fromState(
        strokes: strokes,
        heroes: heroes,
        selectedHeroId: selectedHeroId,
      ),
    );

    final snapshot = _undoStack.removeLast();
    setState(() => _restoreSnapshot(snapshot));
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    _undoStack.add(
      _EditorSnapshot.fromState(
        strokes: strokes,
        heroes: heroes,
        selectedHeroId: selectedHeroId,
      ),
    );

    final snapshot = _redoStack.removeLast();
    setState(() => _restoreSnapshot(snapshot));
  }

  void _resetTransform() {
    setState(() {
      _scale = 1.0;
      _transform = Matrix4.identity();
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    final local = event.localPosition;
    _pointers[event.pointer] = local;

    if (_pointers.length >= 2) {
      currentStroke = null;
      _movingHero = null;
      _heroDragOffset = null;
      _wasMultiTouch = true;

      final points = _pointers.values.toList();
      _lastFocalPoint = _focalPoint(points);
      _lastDistance = _distance(points);
      return;
    }

    if (_pointers.length != 1 || _wasMultiTouch) return;

    final scenePosition = _screenToScene(local);
    final hero = _hitTestHero(scenePosition);

    if (hero != null) {
      _saveHistory();
      setState(() {
        selectedHeroId = hero.id;
        _movingHero = hero;
        _heroDragOffset = scenePosition - hero.position;
      });
      return;
    }

    setState(() {
      selectedHeroId = null;
    });
    _startDrawing(local, saveHistory: true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;

    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2) {
      _updateTwoFingerTransform();
      return;
    }

    if (_pointers.length != 1 || _wasMultiTouch) return;

    if (_movingHero != null) {
      final scenePosition = _screenToScene(event.localPosition);
      final offset = _heroDragOffset ?? Offset.zero;
      setState(() {
        _movingHero!.position = scenePosition - offset;
      });
      return;
    }

    _updateDrawing(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);

    if (_pointers.length >= 2) {
      final points = _pointers.values.toList();
      _lastFocalPoint = _focalPoint(points);
      _lastDistance = _distance(points);
      return;
    }

    if (_wasMultiTouch) {
      currentStroke = null;
      _movingHero = null;
      _heroDragOffset = null;
      _lastFocalPoint = null;
      _lastDistance = null;
      return;
    }

    if (_movingHero != null) {
      _movingHero = null;
      _heroDragOffset = null;
      return;
    }

    _endDrawing();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    currentStroke = null;
    _movingHero = null;
    _heroDragOffset = null;

    if (_pointers.isEmpty) {
      _wasMultiTouch = false;
      _lastFocalPoint = null;
      _lastDistance = null;
    }
  }

  Offset _focalPoint(List<Offset> points) {
    double x = 0;
    double y = 0;
    for (final point in points) {
      x += point.dx;
      y += point.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  double _distance(List<Offset> points) {
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  void _updateTwoFingerTransform() {
    if (_pointers.length < 2) return;

    final points = _pointers.values.toList();
    final focal = _focalPoint(points);
    final distance = _distance(points);

    if (_lastFocalPoint == null ||
        _lastDistance == null ||
        _lastDistance == 0) {
      _lastFocalPoint = focal;
      _lastDistance = distance;
      return;
    }

    final delta = focal - _lastFocalPoint!;
    var scaleFactor = distance / _lastDistance!;
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      scaleFactor = 1.0;
    }

    final newScale = (_scale * scaleFactor).clamp(0.5, 8.0);
    final actualScale = newScale / _scale;

    final Matrix4 next = Matrix4.identity();
    next.translateByDouble(focal.dx, focal.dy, 0, 1);
    next.scaleByDouble(actualScale, actualScale, 1, 1);
    next.translateByDouble(-focal.dx, -focal.dy, 0, 1);
    next.translateByDouble(delta.dx, delta.dy, 0, 1);
    next.multiply(_transform);

    setState(() {
      _transform = next;
      _scale = newScale;
    });

    _lastFocalPoint = focal;
    _lastDistance = distance;
  }

  void _startDrawing(Offset screenPosition, {required bool saveHistory}) {
    if (saveHistory) _saveHistory();

    final scenePosition = _screenToScene(screenPosition);
    final stroke = DrawingStroke(points: [scenePosition], brushSize: brushSize);

    setState(() {
      currentStroke = stroke;
      strokes.add(stroke);
    });
  }

  void _updateDrawing(Offset screenPosition) {
    final stroke = currentStroke;
    if (stroke == null) return;

    final scenePosition = _screenToScene(screenPosition);
    if (stroke.points.isNotEmpty) {
      final last = stroke.points.last;
      if ((scenePosition - last).distance < 1.0) return;
    }

    setState(() => stroke.points.add(scenePosition));
  }

  void _endDrawing() {
    currentStroke = null;
  }

  Offset _screenToScene(Offset screenPosition) {
    final inverse = Matrix4.inverted(_transform);
    return MatrixUtils.transformPoint(inverse, screenPosition);
  }

  HeroObject? _hitTestHero(Offset scenePosition) {
    for (final hero in heroes.reversed) {
      final local = scenePosition - hero.position;
      final cosA = math.cos(-hero.rotation);
      final sinA = math.sin(-hero.rotation);
      final rotated = Offset(
        local.dx * cosA - local.dy * sinA,
        local.dx * sinA + local.dy * cosA,
      );

      const baseWidth = 92.0;
      const baseHeight = 128.0;
      final halfW = baseWidth * hero.scale / 2;
      final halfH = baseHeight * hero.scale / 2;

      if (rotated.dx.abs() <= halfW && rotated.dy.abs() <= halfH) {
        return hero;
      }
    }
    return null;
  }

  void _addHero(_HeroDefinition definition, Size canvasSize) {
    _saveHistory();

    final hero = HeroObject(
      id: 'hero_${++_heroCounter}',
      name: definition.name,
      assetPath: definition.assetPath,
      position: Offset(canvasSize.width / 2, canvasSize.height / 2),
      scale: 1.0,
    );

    setState(() {
      heroes.add(hero);
      selectedHeroId = hero.id;
    });

    Navigator.pop(context);
  }

  void _deleteSelectedHero() {
    final hero = _selectedHero;
    if (hero == null) return;

    _saveHistory();
    setState(() {
      heroes.removeWhere((e) => e.id == hero.id);
      selectedHeroId = null;
    });
  }

  void _duplicateSelectedHero() {
    final hero = _selectedHero;
    if (hero == null) return;

    _saveHistory();
    final copy = hero.copy();
    final newHero = HeroObject(
      id: 'hero_${++_heroCounter}',
      name: copy.name,
      assetPath: copy.assetPath,
      position: copy.position + const Offset(28, 28),
      scale: copy.scale,
      rotation: copy.rotation,
    );

    setState(() {
      heroes.add(newHero);
      selectedHeroId = newHero.id;
    });
  }

  void _resizeSelectedHero(double factor) {
    final hero = _selectedHero;
    if (hero == null) return;

    _saveHistory();
    setState(() {
      hero.scale = (hero.scale * factor).clamp(0.35, 3.0);
    });
  }

  void _rotateSelectedHero(double radians) {
    final hero = _selectedHero;
    if (hero == null) return;

    _saveHistory();
    setState(() {
      hero.rotation += radians;
    });
  }

  void _showHeroPicker(Size canvasSize) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panelDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: cyanColor),
                    const SizedBox(width: 10),
                    Text(
                      'Add Hero',
                      style: _font(
                        size: 18,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: heroDefinitions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (context, index) {
                    final definition = heroDefinitions[index];
                    return Material(
                      color: const Color(0xFF171C2E),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _addHero(definition, canvasSize),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Column(
                            children: [
                              Expanded(
                                child: Image.asset(
                                  definition.assetPath,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                definition.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _font(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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
            Expanded(child: _buildCanvas()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final canUndo = _undoStack.isNotEmpty;
    final canRedo = _redoStack.isNotEmpty;
    final hasSelection = _selectedHero != null;

    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 28),
        color: Colors.white,
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
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
                hasSelection
                    ? _selectedHero!.name
                    : '1 jari coret • 2 jari zoom',
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
        IconButton(
          tooltip: 'Reset zoom',
          onPressed: _resetTransform,
          icon: const Icon(Icons.center_focus_strong_rounded, size: 22),
          color: Colors.white,
        ),
        IconButton(
          tooltip: 'Undo',
          onPressed: canUndo ? _undo : null,
          icon: const Icon(Icons.undo_rounded, size: 23),
          color: canUndo ? Colors.white : const Color(0xFF454C60),
        ),
        IconButton(
          tooltip: 'Redo',
          onPressed: canRedo ? _redo : null,
          icon: const Icon(Icons.redo_rounded, size: 23),
          color: canRedo ? Colors.white : const Color(0xFF454C60),
        ),
        const SizedBox(width: 2),
      ],
    );
  }

  Widget _buildCanvas() {
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
            _canvasSize = Size(viewportWidth, viewportHeight);

            final widthRatio = viewportWidth / imageWidth;
            final heightRatio = viewportHeight / imageHeight;
            final fitScale = widthRatio < heightRatio
                ? widthRatio
                : heightRatio;

            final imageWidthOnScreen = imageWidth * fitScale;
            final imageHeightOnScreen = imageHeight * fitScale;
            final imageLeft = (viewportWidth - imageWidthOnScreen) / 2;
            final imageTop = (viewportHeight - imageHeightOnScreen) / 2;

            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: ClipRect(
                child: Transform(
                  alignment: Alignment.topLeft,
                  transform: _transform,
                  child: SizedBox(
                    width: viewportWidth,
                    height: viewportHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: imageLeft,
                          top: imageTop,
                          width: imageWidthOnScreen,
                          height: imageHeightOnScreen,
                          child: Image.memory(
                            widget.image,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DrawingPainter(strokes: strokes),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Stack(
                              children: heroes.map((hero) {
                                return Positioned(
                                  left: hero.position.dx - (46 * hero.scale),
                                  top: hero.position.dy - (64 * hero.scale),
                                  width: 92 * hero.scale,
                                  height: 128 * hero.scale,
                                  child: Transform.rotate(
                                    angle: hero.rotation,
                                    child: Image.asset(
                                      hero.assetPath,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _HeroPainter(
                                heroes: heroes,
                                selectedHeroId: selectedHeroId,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final hero = _selectedHero;

    if (hero != null) {
      return _buildHeroBar(hero);
    }

    return _buildBrushBar();
  }

  Widget _buildHeroBar(HeroObject hero) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: panelDark,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          _toolButton(
            icon: Icons.remove_rounded,
            label: 'Kecil',
            onTap: () => _resizeSelectedHero(0.88),
          ),
          _toolButton(
            icon: Icons.add_rounded,
            label: 'Besar',
            onTap: () => _resizeSelectedHero(1.14),
          ),
          _toolButton(
            icon: Icons.rotate_left_rounded,
            label: 'Putar',
            onTap: () => _rotateSelectedHero(-0.15),
          ),
          _toolButton(
            icon: Icons.rotate_right_rounded,
            label: 'Putar',
            onTap: () => _rotateSelectedHero(0.15),
          ),
          _toolButton(
            icon: Icons.copy_rounded,
            label: 'Duplikat',
            onTap: _duplicateSelectedHero,
          ),
          _toolButton(
            icon: Icons.delete_outline_rounded,
            label: 'Hapus',
            onTap: _deleteSelectedHero,
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: _font(
                    size: 9,
                    weight: FontWeight.w600,
                    color: const Color(0xFF9DA6BA),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrushBar() {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: const BoxDecoration(
        color: panelDark,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Material(
            color: activeColor,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () {
                _showHeroPicker(_canvasSize);
              },
              child: const SizedBox(
                width: 54,
                height: 58,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: cyanColor, size: 25),
                    SizedBox(height: 1),
                    Text(
                      'HERO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.brush_rounded,
              color: Colors.white70,
              size: 20,
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
                    child: Material(
                      color: active ? activeColor : const Color(0xFF171C2E),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () {
                          setState(() => brushSize = size);
                        },
                        child: SizedBox(
                          height: 58,
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
                                  color: active
                                      ? Colors.white
                                      : const Color(0xFF9DA6BA),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = Colors.red
        ..strokeWidth = stroke.brushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.brushSize / 2,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length - 1; i++) {
        final current = stroke.points[i];
        final next = stroke.points[i + 1];
        final midpoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }

      final previous = stroke.points[stroke.points.length - 2];
      final last = stroke.points.last;
      path.quadraticBezierTo(previous.dx, previous.dy, last.dx, last.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

class _HeroPainter extends CustomPainter {
  final List<HeroObject> heroes;
  final String? selectedHeroId;

  _HeroPainter({required this.heroes, required this.selectedHeroId});

  @override
  void paint(Canvas canvas, Size size) {
    for (final hero in heroes) {
      if (hero.id != selectedHeroId) continue;

      canvas.save();
      canvas.translate(hero.position.dx, hero.position.dy);
      canvas.rotate(hero.rotation);
      canvas.scale(hero.scale);

      final borderPaint = Paint()
        ..color = const Color(0xFF00D9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / hero.scale;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 92, height: 128),
          const Radius.circular(10),
        ),
        borderPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter oldDelegate) => true;
}
