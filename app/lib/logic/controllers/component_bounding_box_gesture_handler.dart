import 'dart:ui';

import '../models/drag_handle.dart';

/// Handler responsible for hit-testing and calculating bounding box transformations
/// during gesture interactions (drag & resize) in normalized coordinate space.
class ComponentBoundingBoxGestureHandler {
  const ComponentBoundingBoxGestureHandler();

  static const double defaultHitTestThreshold = 24.0;

  /// Detects which [DragHandle] (if any) is under [localPos] relative to [rect] in local pixel coordinates.
  DragHandle hitTest(
    Offset localPos,
    Rect rect, {
    double threshold = defaultHitTestThreshold,
  }) {
    // Check corners
    if ((localPos - rect.topLeft).distance <= threshold) {
      return DragHandle.topLeft;
    } else if ((localPos - rect.topRight).distance <= threshold) {
      return DragHandle.topRight;
    } else if ((localPos - rect.bottomLeft).distance <= threshold) {
      return DragHandle.bottomLeft;
    } else if ((localPos - rect.bottomRight).distance <= threshold) {
      return DragHandle.bottomRight;
    }
    // Check edge midpoints
    else if ((localPos - Offset((rect.left + rect.right) / 2, rect.top))
            .distance <=
        threshold) {
      return DragHandle.top;
    } else if ((localPos - Offset((rect.left + rect.right) / 2, rect.bottom))
            .distance <=
        threshold) {
      return DragHandle.bottom;
    } else if ((localPos - Offset(rect.left, (rect.top + rect.bottom) / 2))
            .distance <=
        threshold) {
      return DragHandle.left;
    } else if ((localPos - Offset(rect.right, (rect.top + rect.bottom) / 2))
            .distance <=
        threshold) {
      return DragHandle.right;
    }
    // Check center/move
    else if (rect.contains(localPos)) {
      return DragHandle.center;
    } else {
      return DragHandle.none;
    }
  }

  /// Computes the new normalised bounding box after applying a drag delta.
  ///
  /// All coordinates are in the normalised [0, 1] coordinate space used by
  /// [PixelArtComponent.relativeBoundingBox].
  Rect? applyDelta({
    required DragHandle handle,
    required Rect startRect,
    required Offset pixelDelta,
    required double canvasSize,
    required int gridSize,
  }) {
    if (canvasSize <= 0 || gridSize <= 0) {
      return null;
    }

    final minSize = 1.0 / gridSize;
    final deltaX = pixelDelta.dx / canvasSize;
    final deltaY = pixelDelta.dy / canvasSize;

    switch (handle) {
      case DragHandle.topLeft:
        double newLeft = snapToGrid(startRect.left + deltaX, gridSize);
        double newTop = snapToGrid(startRect.top + deltaY, gridSize);
        double newWidth = startRect.right - newLeft;
        double newHeight = startRect.bottom - newTop;
        if (newWidth < minSize) {
          newLeft = startRect.right - minSize;
          newWidth = minSize;
        }
        if (newHeight < minSize) {
          newTop = startRect.bottom - minSize;
          newHeight = minSize;
        }
        return Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);

      case DragHandle.topRight:
        double newTop = snapToGrid(startRect.top + deltaY, gridSize);
        double newWidth = snapToGrid(startRect.width + deltaX, gridSize);
        double newHeight = startRect.bottom - newTop;
        if (newWidth < minSize) newWidth = minSize;
        if (newHeight < minSize) {
          newTop = startRect.bottom - minSize;
          newHeight = minSize;
        }
        return Rect.fromLTWH(startRect.left, newTop, newWidth, newHeight);

      case DragHandle.bottomLeft:
        double newLeft = snapToGrid(startRect.left + deltaX, gridSize);
        double newWidth = startRect.right - newLeft;
        double newHeight = snapToGrid(startRect.height + deltaY, gridSize);
        if (newWidth < minSize) {
          newLeft = startRect.right - minSize;
          newWidth = minSize;
        }
        if (newHeight < minSize) newHeight = minSize;
        return Rect.fromLTWH(newLeft, startRect.top, newWidth, newHeight);

      case DragHandle.bottomRight:
        double newWidth = snapToGrid(startRect.width + deltaX, gridSize);
        double newHeight = snapToGrid(startRect.height + deltaY, gridSize);
        if (newWidth < minSize) newWidth = minSize;
        if (newHeight < minSize) newHeight = minSize;
        return Rect.fromLTWH(
          startRect.left,
          startRect.top,
          newWidth,
          newHeight,
        );

      case DragHandle.top:
        double newTop = snapToGrid(startRect.top + deltaY, gridSize);
        double newHeight = startRect.bottom - newTop;
        if (newHeight < minSize) {
          newTop = startRect.bottom - minSize;
          newHeight = minSize;
        }
        return Rect.fromLTWH(
          startRect.left,
          newTop,
          startRect.width,
          newHeight,
        );

      case DragHandle.bottom:
        double newHeight = snapToGrid(startRect.height + deltaY, gridSize);
        if (newHeight < minSize) newHeight = minSize;
        return Rect.fromLTWH(
          startRect.left,
          startRect.top,
          startRect.width,
          newHeight,
        );

      case DragHandle.left:
        double newLeft = snapToGrid(startRect.left + deltaX, gridSize);
        double newWidth = startRect.right - newLeft;
        if (newWidth < minSize) {
          newLeft = startRect.right - minSize;
          newWidth = minSize;
        }
        return Rect.fromLTWH(
          newLeft,
          startRect.top,
          newWidth,
          startRect.height,
        );

      case DragHandle.right:
        double newWidth = snapToGrid(startRect.width + deltaX, gridSize);
        if (newWidth < minSize) newWidth = minSize;
        return Rect.fromLTWH(
          startRect.left,
          startRect.top,
          newWidth,
          startRect.height,
        );

      case DragHandle.center:
        double newLeft = snapToGrid(startRect.left + deltaX, gridSize);
        double newTop = snapToGrid(startRect.top + deltaY, gridSize);
        newLeft = newLeft.clamp(0.0, 1.0 - startRect.width);
        newTop = newTop.clamp(0.0, 1.0 - startRect.height);
        return Rect.fromLTWH(
          newLeft,
          newTop,
          startRect.width,
          startRect.height,
        );

      case DragHandle.none:
        return null;
    }
  }

  /// Snaps a normalised [value] to the nearest grid line, clamped to [0, 1].
  double snapToGrid(double value, int gridSize) {
    if (gridSize <= 0) return value.clamp(0.0, 1.0);
    return ((value * gridSize).round() / gridSize).clamp(0.0, 1.0);
  }
}
