import 'package:flutter/material.dart';

class SceneConverter {
  final TransformationController controller;

  const SceneConverter({required this.controller});

  /// Screen -> Scene
  Offset screenToScene(Offset screenPoint) {
    return controller.toScene(screenPoint);
  }

  /// Scene -> Screen
  Offset sceneToScreen(Offset scenePoint) {
    return MatrixUtils.transformPoint(controller.value, scenePoint);
  }

  /// List Screen -> Scene
  List<Offset> screenListToScene(Iterable<Offset> points) {
    return points.map(screenToScene).toList();
  }

  /// List Scene -> Screen
  List<Offset> sceneListToScreen(Iterable<Offset> points) {
    return points.map(sceneToScreen).toList();
  }

  /// Current zoom
  double get scale {
    return controller.value.getMaxScaleOnAxis();
  }

  /// Reset camera
  void reset() {
    controller.value = Matrix4.identity();
  }

  /// Current matrix
  Matrix4 get matrix => controller.value;
}
