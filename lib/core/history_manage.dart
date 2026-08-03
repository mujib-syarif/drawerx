import '../models/draw_stroke.dart';

class HistoryManager {
  final List<DrawStroke> _undoStack = [];
  final List<DrawStroke> _redoStack = [];

  List<DrawStroke> get undoStack => List.unmodifiable(_undoStack);

  List<DrawStroke> get redoStack => List.unmodifiable(_redoStack);

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  /// Tambah object baru
  void push(DrawStroke stroke) {
    _undoStack.add(stroke);

    // Setelah ada aksi baru,
    // redo otomatis dibersihkan.
    _redoStack.clear();
  }

  /// Undo
  DrawStroke? undo() {
    if (_undoStack.isEmpty) return null;

    final stroke = _undoStack.removeLast();

    _redoStack.add(stroke);

    return stroke;
  }

  /// Redo
  DrawStroke? redo() {
    if (_redoStack.isEmpty) return null;

    final stroke = _redoStack.removeLast();

    _undoStack.add(stroke);

    return stroke;
  }

  /// Hapus semua history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
