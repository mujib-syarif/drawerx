import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

class EditorPage extends StatefulWidget {
  final Uint8List image;

  const EditorPage({super.key, required this.image});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class DrawingStroke {
  final List<Offset> points;
  final double brushSize;
  final Color color;

  DrawingStroke({
    required this.points,
    required this.brushSize,
    required this.color,
  });

  DrawingStroke copy() => DrawingStroke(
    points: List<Offset>.from(points),
    brushSize: brushSize,
    color: color,
  );
}

class HeroObject {
  final String id;
  final String name;
  final String assetPath;
  Offset position;
  double scale;
  double rotation;
  final double baseWidth;
  final double baseHeight;

  HeroObject({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.baseWidth = _EditorPageState.heroBaseWidth,
    this.baseHeight = _EditorPageState.heroBaseHeight,
  });

  HeroObject copy() => HeroObject(
    id: id,
    name: name,
    assetPath: assetPath,
    position: position,
    scale: scale,
    rotation: rotation,
    baseWidth: baseWidth,
    baseHeight: baseHeight,
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
  Rect _imageRect = Rect.zero;
  Size _imageSize = Size.zero;
  bool _saving = false;
  double _fitScale = 1.0;

  final Map<int, Offset> _pointers = {};
  Offset? _lastFocalPoint;
  double? _lastDistance;
  bool _wasMultiTouch = false;
  Offset? _pendingDrawStart;

  HeroObject? _movingHero;
  bool _heroMoved = false;
  Offset? _heroDragOffset;

  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];
  int _heroCounter = 0;

  double brushSize = 8.0;
  Color brushColor = Colors.red;

  static const List<Color> brushColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.white,
  ];

  // Ukuran dasar Hero (dp layar pada zoom 1x). Skala awal 0.62 menghasilkan
  // Hero sekitar 55x75 dp: cukup kecil agar tidak menutupi base, tetapi masih
  // terlihat dan mudah disentuh.
  static const double heroBaseWidth = 88.0;
  static const double heroBaseHeight = 120.0;
  static const double heroDefaultScale = 0.62;

  // Area sentuh minimum Hero (dp layar).
  static const double minTouchTarget = 48.0;

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
    _decodedImage = _decodeImage(widget.image);
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    // Gambar dasar hanya dipakai lewat Image.memory dan saat ekspor, jadi
    // aman dilepas di sini.
    _decodedImage.then<void>(
      (image) => image.dispose(),
      onError: (Object error, StackTrace stackTrace) {},
    );
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

  void _cancelDrawingForMultiTouch() {
    final stroke = currentStroke;
    if (stroke == null) {
      _pendingDrawStart = null;
      return;
    }

    // _startDrawing() selalu menyimpan satu snapshot sebelum menambahkan
    // stroke. Karena stroke ini belum selesai, hapus keduanya dari history.
    if (strokes.isNotEmpty && identical(strokes.last, stroke)) {
      strokes.removeLast();
    }
    if (_undoStack.isNotEmpty) {
      _undoStack.removeLast();
    }

    currentStroke = null;
    _pendingDrawStart = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    final local = event.localPosition;
    _pointers[event.pointer] = local;

    if (_pointers.length >= 2) {
      // Jika jari pertama sempat mulai menggambar sebelum jari kedua masuk,
      // batalkan stroke yang sedang berlangsung. Dengan begitu gesture pinch
      // tidak pernah meninggalkan titik/coretan dari sentuhan pertama.
      _cancelDrawingForMultiTouch();
      _pendingDrawStart = null;
      _movingHero = null;
      _heroDragOffset = null;
      _wasMultiTouch = true;

      final points = _pointers.values.toList();
      _lastFocalPoint = _focalPoint(points);
      _lastDistance = _distance(points);
      return;
    }

    if (_pointers.length != 1 || _wasMultiTouch) return;

    final imagePosition = _screenToImage(local);
    final hero = _hitTestHero(imagePosition);

    if (hero != null) {
      _pendingDrawStart = null;
      _heroMoved = false;
      _saveHistory();
      setState(() {
        selectedHeroId = hero.id;
        _movingHero = hero;
        _heroDragOffset = imagePosition - hero.position;
      });
      return;
    }

    setState(() {
      selectedHeroId = null;
    });

    // Tunda pembuatan stroke sampai pointer bergerak atau dilepas.
    // Ini mencegah titik kecil muncul dari jari pertama saat pinch dimulai.
    _pendingDrawStart = local;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;

    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2) {
      _pendingDrawStart = null;
      _updateTwoFingerTransform();
      return;
    }

    if (_pointers.length != 1 || _wasMultiTouch) return;

    if (_movingHero != null) {
      _pendingDrawStart = null;
      final imagePosition = _screenToImage(event.localPosition);
      final offset = _heroDragOffset ?? Offset.zero;
      _heroMoved = true;
      setState(() {
        _movingHero!.position = imagePosition - offset;
      });
      return;
    }

    if (currentStroke == null && _pendingDrawStart != null) {
      final startPosition = _pendingDrawStart!;
      _pendingDrawStart = null;
      _startDrawing(startPosition, saveHistory: true);
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
      _pendingDrawStart = null;
      currentStroke = null;
      _movingHero = null;
      _heroDragOffset = null;
      _lastFocalPoint = null;
      _lastDistance = null;

      if (_pointers.isEmpty) {
        _wasMultiTouch = false;
      }
      return;
    }

    if (_movingHero != null) {
      // Tap tanpa geser hanya memilih hero; jangan tinggalkan snapshot undo kosong.
      if (!_heroMoved && _undoStack.isNotEmpty) {
        _undoStack.removeLast();
      }
      _heroMoved = false;
      _movingHero = null;
      _heroDragOffset = null;
      _pendingDrawStart = null;
      return;
    }

    // Tap tanpa gerakan bukan stroke. Stroke hanya dibuat setelah pointer
    // benar-benar bergerak, sehingga sentuhan awal tidak meninggalkan titik.
    _pendingDrawStart = null;
    _endDrawing();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    currentStroke = null;
    _movingHero = null;
    _heroDragOffset = null;
    _pendingDrawStart = null;

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

    final newScale = (_scale * scaleFactor).clamp(0.5, 20.0);
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

  Offset _screenToScene(Offset screenPosition) {
    final inverse = Matrix4.inverted(_transform);
    return MatrixUtils.transformPoint(inverse, screenPosition);
  }

  Offset _screenToImage(Offset screenPosition) {
    final scene = _screenToScene(screenPosition);
    return Offset(
      (scene.dx - _imageRect.left) / _fitScale,
      (scene.dy - _imageRect.top) / _fitScale,
    );
  }

  bool _imageContains(Offset imagePosition) {
    return imagePosition.dx >= 0 &&
        imagePosition.dy >= 0 &&
        imagePosition.dx <= _imageSize.width &&
        imagePosition.dy <= _imageSize.height;
  }

  void _startDrawing(Offset screenPosition, {required bool saveHistory}) {
    final imagePosition = _screenToImage(screenPosition);
    if (!_imageContains(imagePosition)) return;

    if (saveHistory) _saveHistory();

    // Ukuran kuas di layar tetap (dp) walau di-zoom: bagi dengan fitScale dan
    // zoom. Disimpan dalam piksel gambar agar ikut gambar saat pan/rotasi.
    final effectiveScale = _fitScale * _scale;

    final stroke = DrawingStroke(
      points: [imagePosition],
      brushSize: brushSize / effectiveScale,
      color: brushColor,
    );

    setState(() {
      currentStroke = stroke;
      strokes.add(stroke);
    });
  }

  void _updateDrawing(Offset screenPosition) {
    final stroke = currentStroke;
    if (stroke == null) return;

    // Titik di luar gambar di-clamp ke tepi, bukan dibuang, agar goresan
    // yang keluar batas tidak putus.
    final rawPosition = _screenToImage(screenPosition);
    final imagePosition = Offset(
      rawPosition.dx.clamp(0.0, _imageSize.width).toDouble(),
      rawPosition.dy.clamp(0.0, _imageSize.height).toDouble(),
    );
    if (stroke.points.isNotEmpty) {
      final last = stroke.points.last;
      if ((imagePosition - last).distance < (1.0 / (_fitScale * _scale))) {
        return;
      }
    }

    setState(() => stroke.points.add(imagePosition));
  }

  void _endDrawing() {
    currentStroke = null;
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

      // Area sentuh minimal 48 dp layar (dikonversi ke piksel gambar).
      final minHalf = minTouchTarget / 2 / (_fitScale * _scale);
      final halfW = math.max(hero.baseWidth * hero.scale / 2, minHalf);
      final halfH = math.max(hero.baseHeight * hero.scale / 2, minHalf);

      if (rotated.dx.abs() <= halfW && rotated.dy.abs() <= halfH) {
        return hero;
      }
    }
    return null;
  }

  void _addHero(_HeroDefinition definition) {
    _saveHistory();

    final hero = HeroObject(
      id: 'hero_${++_heroCounter}',
      name: definition.name,
      assetPath: definition.assetPath,
      position: Offset(_imageSize.width / 2, _imageSize.height / 2),
      scale: heroDefaultScale,
      baseWidth: heroBaseWidth / _fitScale,
      baseHeight: heroBaseHeight / _fitScale,
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
      position: copy.position + Offset(28 / _fitScale, 28 / _fitScale),
      scale: copy.scale,
      rotation: copy.rotation,
      baseWidth: copy.baseWidth,
      baseHeight: copy.baseHeight,
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
      hero.scale = (hero.scale * factor).clamp(0.1, 2.5);
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

  void _showHeroPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panelDark,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final cardWidth = landscape ? 118.0 : 112.0;
            final imageHeight = landscape ? 100.0 : 118.0;

            return SizedBox(
              height: landscape ? 205 : 230,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: cyanColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'Add Hero',
                          style: _font(
                            size: 17,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Geser →',
                          style: _font(
                            size: 11,
                            weight: FontWeight.w600,
                            color: const Color(0xFF7F899F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: heroDefinitions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final definition = heroDefinitions[index];
                          return SizedBox(
                            width: cardWidth,
                            child: Material(
                              color: const Color(0xFF171C2E),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _addHero(definition),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    5,
                                    6,
                                    6,
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: imageHeight,
                                        child: Image.asset(
                                          definition.assetPath,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        definition.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: _font(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUndo = _undoStack.isNotEmpty;
    final canRedo = _redoStack.isNotEmpty;

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
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _buildCanvas()),
                  _buildBottomBar(),
                ],
              ),
              Positioned(
                left: 8,
                top: 8,
                child: _floatingIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Kembali',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _floatingIconButton(
                      icon: Icons.save_alt_rounded,
                      tooltip: 'Simpan ke galeri',
                      onTap: _saving ? null : _saveImage,
                    ),
                    const SizedBox(width: 4),
                    _floatingIconButton(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: 'Reset zoom',
                      onTap: _resetTransform,
                    ),
                    const SizedBox(width: 4),
                    _floatingIconButton(
                      icon: Icons.undo_rounded,
                      tooltip: 'Undo',
                      onTap: canUndo ? _undo : null,
                    ),
                    const SizedBox(width: 4),
                    _floatingIconButton(
                      icon: Icons.redo_rounded,
                      tooltip: 'Redo',
                      onTap: canRedo ? _redo : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Merender gambar dasar + goresan + hero ke PNG pada resolusi asli gambar.
  Future<Uint8List> _renderPng() async {
    final base = await _decodedImage;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(
      base,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.high,
    );
    _paintStrokes(canvas, strokes);

    final heroImages = <String, ui.Image>{};
    try {
      for (final hero in heroes) {
        var heroImage = heroImages[hero.assetPath];
        if (heroImage == null) {
          final data = await rootBundle.load(hero.assetPath);
          heroImage = await _decodeImage(data.buffer.asUint8List());
          heroImages[hero.assetPath] = heroImage;
        }

        // Sama dengan BoxFit.contain pada tampilan layar.
        final boxWidth = hero.baseWidth * hero.scale;
        final boxHeight = hero.baseHeight * hero.scale;
        final imageWidth = heroImage.width.toDouble();
        final imageHeight = heroImage.height.toDouble();
        final fit = math.min(boxWidth / imageWidth, boxHeight / imageHeight);

        canvas.save();
        canvas.translate(hero.position.dx, hero.position.dy);
        canvas.rotate(hero.rotation);
        canvas.drawImageRect(
          heroImage,
          Rect.fromLTWH(0, 0, imageWidth, imageHeight),
          Rect.fromCenter(
            center: Offset.zero,
            width: imageWidth * fit,
            height: imageHeight * fit,
          ),
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      }

      final picture = recorder.endRecording();
      ui.Image? output;
      try {
        output = await picture.toImage(base.width, base.height);
        final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          throw StateError('Gagal meng-encode PNG');
        }
        return bytes.buffer.asUint8List();
      } finally {
        output?.dispose();
        picture.dispose();
      }
    } finally {
      for (final image in heroImages.values) {
        image.dispose();
      }
    }
  }

  Future<void> _saveImage() async {
    if (_saving) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    String message;
    try {
      final bytes = await _renderPng();
      await PhotoManager.editor.saveImage(
        bytes,
        filename: 'drawerx_${DateTime.now().millisecondsSinceEpoch}.png',
        relativePath: 'Pictures/DrawerX',
      );
      message = 'Tersimpan ke galeri (Pictures/DrawerX)';
    } on PlatformException catch (e) {
      debugPrint('Save error: ${e.message}');
      message = 'Gagal menyimpan gambar';
    } on MissingPluginException catch (e) {
      debugPrint('Save error: ${e.message}');
      message = 'Gagal menyimpan gambar';
    } catch (e) {
      debugPrint('Save error: $e');
      message = 'Gagal menyimpan gambar';
    }

    if (mounted) {
      setState(() => _saving = false);
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _floatingIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xCC0D1222),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: onTap == null ? const Color(0xFF454C60) : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<ui.Image>(
          future: _decodedImage,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Gagal memuat gambar',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
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
            final fitScale = widthRatio < heightRatio
                ? widthRatio
                : heightRatio;

            _imageSize = Size(imageWidth, imageHeight);
            _fitScale = fitScale;

            final imageWidthOnScreen = imageWidth * fitScale;
            final imageHeightOnScreen = imageHeight * fitScale;
            final imageLeft = (viewportWidth - imageWidthOnScreen) / 2;
            final imageTop = (viewportHeight - imageHeightOnScreen) / 2;
            _imageRect = Rect.fromLTWH(
              imageLeft,
              imageTop,
              imageWidthOnScreen,
              imageHeightOnScreen,
            );

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
                            painter: _DrawingPainter(
                              strokes: strokes,
                              imageRect: _imageRect,
                              fitScale: fitScale,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Stack(
                              children: heroes.map((hero) {
                                final screenX =
                                    imageLeft + hero.position.dx * fitScale;
                                final screenY =
                                    imageTop + hero.position.dy * fitScale;
                                final width =
                                    hero.baseWidth * hero.scale * fitScale;
                                final height =
                                    hero.baseHeight * hero.scale * fitScale;
                                return Positioned(
                                  left: screenX - width / 2,
                                  top: screenY - height / 2,
                                  width: width,
                                  height: height,
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
                                imageRect: _imageRect,
                                fitScale: fitScale,
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
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
        decoration: const BoxDecoration(
          color: panelDark,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 64,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: _font(
                    size: 11,
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

  void _eraseAllStrokes() {
    if (strokes.isEmpty) return;

    _saveHistory();
    setState(() {
      strokes.clear();
      currentStroke = null;
    });
  }

  Widget _buildBrushBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 114,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: const BoxDecoration(
          color: panelDark,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            _brushActionButton(
              icon: Icons.add_rounded,
              label: 'HERO',
              tooltip: 'Tambah hero',
              onTap: _showHeroPicker,
              highlighted: true,
            ),
            const SizedBox(width: 7),
            _brushActionButton(
              icon: Icons.delete_sweep_outlined,
              label: 'HAPUS',
              tooltip: 'Hapus semua coretan',
              onTap: _eraseAllStrokes,
            ),
            const SizedBox(width: 9),
            Expanded(child: _buildBrushSettings()),
          ],
        ),
      ),
    );
  }

  Widget _buildBrushSettings() {
    return Container(
      height: 103,
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 3),
      decoration: BoxDecoration(
        color: const Color(0xFF171C2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.palette_rounded,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 5),
              Text(
                'Warna',
                style: _font(
                  size: 11,
                  weight: FontWeight.w600,
                  color: const Color(0xFF9DA6BA),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(child: _buildColorPicker()),
              const SizedBox(width: 6),
              Text(
                '${brushSize.toStringAsFixed(1)} px',
                style: _font(
                  size: 11,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.brush_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
                Expanded(
                  child: Slider(
                    value: brushSize,
                    min: 1.0,
                    max: 40.0,
                    divisions: 390,
                    label: '${brushSize.toStringAsFixed(1)} px',
                    activeColor: brushColor,
                    inactiveColor: Colors.white12,
                    onChanged: (value) {
                      setState(() => brushSize = value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: brushColors.length,
            itemBuilder: (context, index) {
              final color = brushColors[index];
              final active = brushColor == color;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => brushColor = color),
                // Area sentuh 48x48 dp; lingkaran warna 26 dp di tengah.
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? Colors.white : Colors.white24,
                          width: active ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Petunjuk bahwa daftar warna bisa digeser.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 28,
                alignment: Alignment.centerRight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x00171C2E), Color(0xFF171C2E)],
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brushActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? tooltip,
    bool highlighted = false,
  }) {
    final button = Material(
      color: highlighted ? activeColor : const Color(0xFF171C2E),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: highlighted ? 64 : 72,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: highlighted ? cyanColor : Colors.white,
                size: 23,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(
                  size: 11,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

/// Menggambar semua goresan dalam koordinat piksel gambar. Dipakai oleh
/// painter layar dan oleh ekspor PNG supaya hasilnya identik.
void _paintStrokes(Canvas canvas, List<DrawingStroke> strokes) {
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;

    final paint = Paint()
      ..color = stroke.color
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
          ..color = stroke.color
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

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final Rect imageRect;
  final double fitScale;

  _DrawingPainter({
    required this.strokes,
    required this.imageRect,
    required this.fitScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(imageRect.left, imageRect.top);
    canvas.scale(fitScale);
    _paintStrokes(canvas, strokes);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

class _HeroPainter extends CustomPainter {
  final List<HeroObject> heroes;
  final String? selectedHeroId;
  final Rect imageRect;
  final double fitScale;

  _HeroPainter({
    required this.heroes,
    required this.selectedHeroId,
    required this.imageRect,
    required this.fitScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final hero in heroes) {
      if (hero.id != selectedHeroId) continue;

      final screenPosition = Offset(
        imageRect.left + hero.position.dx * fitScale,
        imageRect.top + hero.position.dy * fitScale,
      );

      canvas.save();
      canvas.translate(screenPosition.dx, screenPosition.dy);
      canvas.rotate(hero.rotation);

      final width = hero.baseWidth * hero.scale * fitScale;
      final height = hero.baseHeight * hero.scale * fitScale;

      final borderPaint = Paint()
        ..color = const Color(0xFF00D9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          Radius.circular(10 * fitScale),
        ),
        borderPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter oldDelegate) => true;
}
