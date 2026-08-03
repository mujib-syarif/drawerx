import 'dart:math';

import 'package:flutter/material.dart';

/// Menghitung area gambar yang tampil di layar saat menggunakan BoxFit.contain.
///
/// Class ini menjadi pusat konversi koordinat:
///
/// Screen Coordinate <-> Image Coordinate
///
/// Nantinya semua tool (Pen, Arrow, Circle, Text, Export)
/// menggunakan class ini.
class ImageViewport {
  final Size imageSize;
  final Size viewportSize;

  late final double scale;
  late final Size fittedSize;
  late final Offset offset;
  late final Rect imageRect;

  ImageViewport({required this.imageSize, required this.viewportSize}) {
    final sx = viewportSize.width / imageSize.width;
    final sy = viewportSize.height / imageSize.height;

    scale = min(sx, sy);

    fittedSize = Size(imageSize.width * scale, imageSize.height * scale);

    offset = Offset(
      (viewportSize.width - fittedSize.width) / 2,
      (viewportSize.height - fittedSize.height) / 2,
    );

    imageRect = offset & fittedSize;
  }

  /// Mengecek apakah titik layar berada di area gambar.
  bool contains(Offset screenPoint) {
    return imageRect.contains(screenPoint);
  }

  /// Screen -> Image Coordinate
  Offset screenToImage(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - offset.dx) / scale,
      (screenPoint.dy - offset.dy) / scale,
    );
  }

  /// Image -> Screen Coordinate
  Offset imageToScreen(Offset imagePoint) {
    return Offset(
      imagePoint.dx * scale + offset.dx,
      imagePoint.dy * scale + offset.dy,
    );
  }

  /// Membatasi koordinat agar tidak keluar gambar.
  Offset clamp(Offset imagePoint) {
    return Offset(
      imagePoint.dx.clamp(0.0, imageSize.width),
      imagePoint.dy.clamp(0.0, imageSize.height),
    );
  }

  @override
  String toString() {
    return '''
ImageViewport(
  imageSize : $imageSize,
  viewport  : $viewportSize,
  scale     : $scale,
  fitted    : $fittedSize,
  offset    : $offset,
)
''';
  }
}
