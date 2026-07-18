import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/agents/base_agent.dart';
import '../logic/agents/shape_sculpter_agent.dart';
import 'wizard_controls.dart';

enum DragHandle {
  none,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
  center,
}

class CanvasGrid extends ConsumerStatefulWidget {
  const CanvasGrid({super.key});

  @override
  ConsumerState<CanvasGrid> createState() => _CanvasGridState();
}

class _CanvasGridState extends ConsumerState<CanvasGrid> {
  DragHandle _activeHandle = DragHandle.none;

  @override
  Widget build(BuildContext context) {
    final canvasModel = ref.watch(canvasStateProvider);
    final wizardState = ref.watch(wizardStateProvider);
    final isSketchingPlanPhase = wizardState.currentStep == 2;
    final isSculptingPhase = wizardState.currentStep == 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);

        Widget gridContent = CustomPaint(
          painter: CanvasPainter(
            grid: canvasModel.grid,
            palette: canvasModel.palette,
            decomposedComponents: canvasModel.decomposedComponents,
            activeComponentIndex: canvasModel.activeComponentIndex,
            isSketchingPlanPhase: isSketchingPlanPhase,
            isSculptingPhase: isSculptingPhase,
            isGenerating: canvasModel.isGenerating,
          ),
          child: GridPaper(
            color: Colors.grey[800]!.withValues(alpha: 0.2),
            divisions: 1,
            subdivisions: 1,
            interval: size / canvasModel.gridSize,
            child: Container(),
          ),
        );

        if (isSketchingPlanPhase &&
            canvasModel.decomposedComponents.isNotEmpty) {
          final activeIndex = canvasModel.activeComponentIndex;
          if (activeIndex >= 0 &&
              activeIndex < canvasModel.decomposedComponents.length) {
            final activeComp = canvasModel.decomposedComponents[activeIndex];
            final relativeRect = activeComp.relativeBoundingBox;
            final rect = Rect.fromLTWH(
              relativeRect.left * size,
              relativeRect.top * size,
              relativeRect.width * size,
              relativeRect.height * size,
            );

            gridContent = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                final localPos = details.localPosition;
                const threshold = 24.0;

                // Check corners
                if ((localPos - rect.topLeft).distance <= threshold) {
                  _activeHandle = DragHandle.topLeft;
                } else if ((localPos - rect.topRight).distance <= threshold) {
                  _activeHandle = DragHandle.topRight;
                } else if ((localPos - rect.bottomLeft).distance <= threshold) {
                  _activeHandle = DragHandle.bottomLeft;
                } else if ((localPos - rect.bottomRight).distance <=
                    threshold) {
                  _activeHandle = DragHandle.bottomRight;
                }
                // Check edge midpoints
                else if ((localPos -
                            Offset((rect.left + rect.right) / 2, rect.top))
                        .distance <=
                    threshold) {
                  _activeHandle = DragHandle.top;
                } else if ((localPos -
                            Offset((rect.left + rect.right) / 2, rect.bottom))
                        .distance <=
                    threshold) {
                  _activeHandle = DragHandle.bottom;
                } else if ((localPos -
                            Offset(rect.left, (rect.top + rect.bottom) / 2))
                        .distance <=
                    threshold) {
                  _activeHandle = DragHandle.left;
                } else if ((localPos -
                            Offset(rect.right, (rect.top + rect.bottom) / 2))
                        .distance <=
                    threshold) {
                  _activeHandle = DragHandle.right;
                }
                // Check center/move
                else if (rect.contains(localPos)) {
                  _activeHandle = DragHandle.center;
                } else {
                  _activeHandle = DragHandle.none;
                }
              },
              onPanUpdate: (details) {
                if (_activeHandle == DragHandle.none) return;

                final localPos = details.localPosition;
                final relativeX = localPos.dx / size;
                final relativeY = localPos.dy / size;
                final clampedX = relativeX.clamp(0.0, 1.0);
                final clampedY = relativeY.clamp(0.0, 1.0);
                final currentRect = activeComp.relativeBoundingBox;
                final minSize = 1.0 / canvasModel.gridSize;

                Rect? newRect;

                switch (_activeHandle) {
                  case DragHandle.topLeft:
                    double newLeft = clampedX;
                    double newTop = clampedY;
                    double newWidth = currentRect.right - newLeft;
                    double newHeight = currentRect.bottom - newTop;
                    if (newWidth < minSize) {
                      newLeft = currentRect.right - minSize;
                      newWidth = minSize;
                    }
                    if (newHeight < minSize) {
                      newTop = currentRect.bottom - minSize;
                      newHeight = minSize;
                    }
                    newRect = Rect.fromLTWH(
                      newLeft,
                      newTop,
                      newWidth,
                      newHeight,
                    );
                    break;
                  case DragHandle.topRight:
                    double newTop = clampedY;
                    double newWidth = clampedX - currentRect.left;
                    double newHeight = currentRect.bottom - newTop;
                    if (newWidth < minSize) newWidth = minSize;
                    if (newHeight < minSize) {
                      newTop = currentRect.bottom - minSize;
                      newHeight = minSize;
                    }
                    newRect = Rect.fromLTWH(
                      currentRect.left,
                      newTop,
                      newWidth,
                      newHeight,
                    );
                    break;
                  case DragHandle.bottomLeft:
                    double newLeft = clampedX;
                    double newWidth = currentRect.right - newLeft;
                    double newHeight = clampedY - currentRect.top;
                    if (newWidth < minSize) {
                      newLeft = currentRect.right - minSize;
                      newWidth = minSize;
                    }
                    if (newHeight < minSize) newHeight = minSize;
                    newRect = Rect.fromLTWH(
                      newLeft,
                      currentRect.top,
                      newWidth,
                      newHeight,
                    );
                    break;
                  case DragHandle.bottomRight:
                    double newWidth = clampedX - currentRect.left;
                    double newHeight = clampedY - currentRect.top;
                    if (newWidth < minSize) newWidth = minSize;
                    if (newHeight < minSize) newHeight = minSize;
                    newRect = Rect.fromLTWH(
                      currentRect.left,
                      currentRect.top,
                      newWidth,
                      newHeight,
                    );
                    break;
                  case DragHandle.top:
                    double newTop = clampedY;
                    double newHeight = currentRect.bottom - newTop;
                    if (newHeight < minSize) {
                      newTop = currentRect.bottom - minSize;
                      newHeight = minSize;
                    }
                    newRect = Rect.fromLTWH(
                      currentRect.left,
                      newTop,
                      currentRect.width,
                      newHeight,
                    );
                    break;
                  case DragHandle.bottom:
                    double newHeight = clampedY - currentRect.top;
                    if (newHeight < minSize) newHeight = minSize;
                    newRect = Rect.fromLTWH(
                      currentRect.left,
                      currentRect.top,
                      currentRect.width,
                      newHeight,
                    );
                    break;
                  case DragHandle.left:
                    double newLeft = clampedX;
                    double newWidth = currentRect.right - newLeft;
                    if (newWidth < minSize) {
                      newLeft = currentRect.right - minSize;
                      newWidth = minSize;
                    }
                    newRect = Rect.fromLTWH(
                      newLeft,
                      currentRect.top,
                      newWidth,
                      currentRect.height,
                    );
                    break;
                  case DragHandle.right:
                    double newWidth = clampedX - currentRect.left;
                    if (newWidth < minSize) newWidth = minSize;
                    newRect = Rect.fromLTWH(
                      currentRect.left,
                      currentRect.top,
                      newWidth,
                      currentRect.height,
                    );
                    break;
                  case DragHandle.center:
                    final deltaX = details.delta.dx / size;
                    final deltaY = details.delta.dy / size;
                    double newLeft = currentRect.left + deltaX;
                    double newTop = currentRect.top + deltaY;
                    newLeft = newLeft.clamp(0.0, 1.0 - currentRect.width);
                    newTop = newTop.clamp(0.0, 1.0 - currentRect.height);
                    newRect = Rect.fromLTWH(
                      newLeft,
                      newTop,
                      currentRect.width,
                      currentRect.height,
                    );
                    break;
                  default:
                    break;
                }

                if (newRect != null) {
                  ref
                      .read(canvasStateProvider.notifier)
                      .updateComponentBoundingBox(activeIndex, newRect);
                }
              },
              onPanEnd: (_) {
                _activeHandle = DragHandle.none;
              },
              child: gridContent,
            );
          }
        }

        if (isSculptingPhase && canvasModel.decomposedComponents.isNotEmpty) {
          final activeIndex = canvasModel.activeComponentIndex;
          if (activeIndex >= 0 &&
              activeIndex < canvasModel.decomposedComponents.length) {
            final activeComp = canvasModel.decomposedComponents[activeIndex];
            if (activeComp.grid != null) {
              gridContent = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  // Only allow if AI is not running
                  if (canvasModel.isGenerating) return;

                  final localPos = details.localPosition;
                  final cellWidth = size / canvasModel.gridSize;
                  final cellHeight = size / canvasModel.gridSize;
                  final col = (localPos.dx / cellWidth).floor().clamp(
                    0,
                    canvasModel.gridSize - 1,
                  );
                  final row = (localPos.dy / cellHeight).floor().clamp(
                    0,
                    canvasModel.gridSize - 1,
                  );

                  // Calculate eligible candidates
                  final candidates = calculateSculptingCandidates(
                    activeComp.grid!,
                    canvasModel.gridSize,
                    activeComp.relativeBoundingBox,
                  );

                  final removeList = candidates['remove'] ?? [];
                  final addList = candidates['add'] ?? [];

                  // Check if tapped pixel is in remove candidates
                  final isRemoveCandidate = removeList.any(
                    (p) => p['x'] == col && p['y'] == row,
                  );
                  if (isRemoveCandidate) {
                    ref
                        .read(canvasStateProvider.notifier)
                        .toggleComponentPixel(activeIndex, col, row, 0);
                    return;
                  }

                  // Check if tapped pixel is in add candidates
                  final isAddCandidate = addList.any(
                    (p) => p['x'] == col && p['y'] == row,
                  );
                  if (isAddCandidate) {
                    ref
                        .read(canvasStateProvider.notifier)
                        .toggleComponentPixel(activeIndex, col, row, 1);
                    return;
                  }
                },
                child: gridContent,
              );
            }
          }
        }

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: gridContent,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<List<int>> grid;
  final List<Color> palette;
  final List<PixelArtComponent> decomposedComponents;
  final int activeComponentIndex;
  final bool isSketchingPlanPhase;
  final bool isSculptingPhase;
  final bool isGenerating;

  CanvasPainter({
    required this.grid,
    required this.palette,
    required this.decomposedComponents,
    required this.activeComponentIndex,
    required this.isSketchingPlanPhase,
    required this.isSculptingPhase,
    required this.isGenerating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = grid.length;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    // Draw solid background to prevent subpixel outline bleeding from the Card background
    final bgBasePaint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgBasePaint);

    // Draw checkerboard transparent background for index 0
    final bgPaint1 = Paint()
      ..color = const Color(0xFF262626)
      ..isAntiAlias = false;
    final bgPaint2 = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..isAntiAlias = false;

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final rect = Rect.fromLTWH(
          x * cellWidth,
          y * cellHeight,
          cellWidth,
          cellHeight,
        );
        final colorIndex = grid[y][x];

        if (colorIndex == 0) {
          final paint = (x + y) % 2 == 0 ? bgPaint1 : bgPaint2;
          canvas.drawRect(rect, paint);
        } else {
          final paint = Paint()
            ..color = palette[colorIndex - 1]
            ..isAntiAlias = false;
          canvas.drawRect(rect, paint);
        }
      }
    }

    // Draw the individual component grids (outlines) as semi-transparent overlays
    for (int i = 0; i < decomposedComponents.length; i++) {
      final comp = decomposedComponents[i];
      final compOutline = comp.getOutlineGrid();
      if (compOutline != null) {
        final compColor = _getComponentColor(i);
        final overlayPaint = Paint()
          ..color = compColor
          ..isAntiAlias = false;

        for (int y = 0; y < gridSize; y++) {
          for (int x = 0; x < gridSize; x++) {
            if (y < compOutline.length &&
                x < compOutline[y].length &&
                compOutline[y][x] > 0) {
              final rect = Rect.fromLTWH(
                x * cellWidth,
                y * cellHeight,
                cellWidth,
                cellHeight,
              );
              canvas.drawRect(rect, overlayPaint);
            }
          }
        }
      }
    }

    // Draw the active component's filled pixels if in sculpting phase
    if (isSculptingPhase && decomposedComponents.isNotEmpty) {
      if (activeComponentIndex >= 0 &&
          activeComponentIndex < decomposedComponents.length) {
        final comp = decomposedComponents[activeComponentIndex];
        if (comp.grid != null) {
          final activeColor = _getComponentColor(
            activeComponentIndex,
          ).withValues(alpha: 0.7);
          final fillPaint = Paint()
            ..color = activeColor
            ..isAntiAlias = false;

          for (int y = 0; y < gridSize; y++) {
            for (int x = 0; x < gridSize; x++) {
              if (comp.grid![y][x] > 0) {
                final rect = Rect.fromLTWH(
                  x * cellWidth,
                  y * cellHeight,
                  cellWidth,
                  cellHeight,
                );
                canvas.drawRect(rect, fillPaint);
              }
            }
          }
        }
      }
    }

    // Highlight eligible sculpting pixels if in sculpting phase and AI is not running
    if (isSculptingPhase && decomposedComponents.isNotEmpty && !isGenerating) {
      if (activeComponentIndex >= 0 &&
          activeComponentIndex < decomposedComponents.length) {
        final comp = decomposedComponents[activeComponentIndex];
        if (comp.grid != null) {
          final candidates = calculateSculptingCandidates(
            comp.grid!,
            gridSize,
            comp.relativeBoundingBox,
          );

          final removeList = candidates['remove'] ?? [];
          final addList = candidates['add'] ?? [];

          final removePaint = Paint()
            ..color = Colors.redAccent.withValues(alpha: 0.3)
            ..isAntiAlias = false;

          final addPaint = Paint()
            ..color = Colors.greenAccent.withValues(alpha: 0.3)
            ..isAntiAlias = false;

          for (final p in removeList) {
            final x = p['x']!;
            final y = p['y']!;
            final rect = Rect.fromLTWH(
              x * cellWidth,
              y * cellHeight,
              cellWidth,
              cellHeight,
            );
            canvas.drawRect(rect, removePaint);
          }

          for (final p in addList) {
            final x = p['x']!;
            final y = p['y']!;
            final rect = Rect.fromLTWH(
              x * cellWidth,
              y * cellHeight,
              cellWidth,
              cellHeight,
            );
            canvas.drawRect(rect, addPaint);
          }
        }
      }
    }

    // Draw component bounding boxes if present
    if (decomposedComponents.isNotEmpty) {
      final borderPaint = Paint()..style = PaintingStyle.stroke;

      for (int i = 0; i < decomposedComponents.length; i++) {
        final comp = decomposedComponents[i];
        final isActive = i == activeComponentIndex;

        final rect = Rect.fromLTWH(
          comp.relativeBoundingBox.left * size.width,
          comp.relativeBoundingBox.top * size.height,
          comp.relativeBoundingBox.width * size.width,
          comp.relativeBoundingBox.height * size.height,
        );

        if (isActive) {
          const activeColor = Colors.tealAccent;
          borderPaint
            ..color = activeColor
            ..strokeWidth = 3.0;
          canvas.drawRect(rect, borderPaint);

          // Draw component name label block at the top-left of the bounding box
          final textPainter = TextPainter(
            text: TextSpan(
              text: ' ${comp.name} ',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final labelBgPaint = Paint()..color = activeColor;
          final labelRect = Rect.fromLTWH(
            rect.left.clamp(0.0, size.width - textPainter.width),
            (rect.top - 14.0).clamp(0.0, size.height - textPainter.height),
            textPainter.width,
            14.0,
          );
          canvas.drawRect(labelRect, labelBgPaint);

          textPainter.paint(canvas, Offset(labelRect.left, labelRect.top));

          // Draw the shapes inside this active component
          if (comp.shapes.isNotEmpty) {
            final shapePaint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0
              ..color = Colors.amberAccent;

            for (final shape in comp.shapes) {
              final shapeRect = Rect.fromLTWH(
                rect.left + shape.relativeBoundingBox.left * rect.width,
                rect.top + shape.relativeBoundingBox.top * rect.height,
                shape.relativeBoundingBox.width * rect.width,
                shape.relativeBoundingBox.height * rect.height,
              );

              if (shape.type == 'circle') {
                final radius = min(shapeRect.width, shapeRect.height) / 2;
                canvas.drawCircle(shapeRect.center, radius, shapePaint);
              } else if (shape.type == 'triangle') {
                final path = Path()
                  ..moveTo(shapeRect.left + shapeRect.width / 2, shapeRect.top)
                  ..lineTo(shapeRect.left, shapeRect.bottom)
                  ..lineTo(shapeRect.right, shapeRect.bottom)
                  ..close();
                canvas.drawPath(path, shapePaint);
              } else {
                // Default to rectangle
                canvas.drawRect(shapeRect, shapePaint);
              }
            }
          }

          // Draw resize handles if in sketching plan phase
          if (isSketchingPlanPhase) {
            final handlePaint = Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill;
            final handleBorderPaint = Paint()
              ..color = activeColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0;

            const handleRadius = 6.0;

            void drawHandle(Offset center) {
              canvas.drawCircle(center, handleRadius, handlePaint);
              canvas.drawCircle(center, handleRadius, handleBorderPaint);
            }

            drawHandle(rect.topLeft);
            drawHandle(rect.topRight);
            drawHandle(rect.bottomLeft);
            drawHandle(rect.bottomRight);

            // Draw edge midpoints
            drawHandle(Offset((rect.left + rect.right) / 2, rect.top));
            drawHandle(Offset((rect.left + rect.right) / 2, rect.bottom));
            drawHandle(Offset(rect.left, (rect.top + rect.bottom) / 2));
            drawHandle(Offset(rect.right, (rect.top + rect.bottom) / 2));
          }
        } else {
          borderPaint
            ..color = Colors.white24
            ..strokeWidth = 1.0;
          canvas.drawRect(rect, borderPaint);
        }
      }
    }
  }

  Color _getComponentColor(int index) {
    final colors = [
      Colors.blue,
      Colors.amber,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.orange,
    ];
    return colors[index % colors.length].withValues(alpha: 0.4);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.palette != palette ||
        oldDelegate.decomposedComponents != decomposedComponents ||
        oldDelegate.activeComponentIndex != activeComponentIndex ||
        oldDelegate.isSketchingPlanPhase != isSketchingPlanPhase ||
        oldDelegate.isSculptingPhase != isSculptingPhase ||
        oldDelegate.isGenerating != isGenerating;
  }
}
