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
  Offset? _dragStartLocalPos;
  Rect? _dragStartRect;

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
                ref.read(isDraggingCanvasProvider.notifier).state = true;
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

                if (_activeHandle != DragHandle.none) {
                  _dragStartLocalPos = localPos;
                  _dragStartRect = activeComp.relativeBoundingBox;
                } else {
                  _dragStartLocalPos = null;
                  _dragStartRect = null;
                }
              },
              onPanUpdate: (details) {
                if (_activeHandle == DragHandle.none ||
                    _dragStartLocalPos == null ||
                    _dragStartRect == null) {
                  return;
                }

                final minSize = 1.0 / canvasModel.gridSize;
                final gridSize = canvasModel.gridSize;

                double snapToGrid(double value) {
                  return ((value * gridSize).round() / gridSize).clamp(
                    0.0,
                    1.0,
                  );
                }

                final delta = details.localPosition - _dragStartLocalPos!;
                final deltaX = delta.dx / size;
                final deltaY = delta.dy / size;

                Rect? newRect;

                switch (_activeHandle) {
                  case DragHandle.topLeft:
                    double newLeft = snapToGrid(_dragStartRect!.left + deltaX);
                    double newTop = snapToGrid(_dragStartRect!.top + deltaY);
                    double newWidth = _dragStartRect!.right - newLeft;
                    double newHeight = _dragStartRect!.bottom - newTop;
                    if (newWidth < minSize) {
                      newLeft = _dragStartRect!.right - minSize;
                      newWidth = minSize;
                    }
                    if (newHeight < minSize) {
                      newTop = _dragStartRect!.bottom - minSize;
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
                    double newTop = snapToGrid(_dragStartRect!.top + deltaY);
                    double newWidth = snapToGrid(
                      _dragStartRect!.width + deltaX,
                    );
                    double newHeight = _dragStartRect!.bottom - newTop;
                    if (newWidth < minSize) newWidth = minSize;
                    if (newHeight < minSize) {
                      newTop = _dragStartRect!.bottom - minSize;
                      newHeight = minSize;
                    }
                    newRect = Rect.fromLTWH(
                      _dragStartRect!.left,
                      newTop,
                      newWidth,
                      newHeight,
                    );
                    break;
                  case DragHandle.bottomLeft:
                    double newLeft = snapToGrid(_dragStartRect!.left + deltaX);
                    double newWidth = _dragStartRect!.right - newLeft;
                    double newHeight = snapToGrid(
                      _dragStartRect!.height + deltaY,
                    );
                    if (newWidth < minSize) {
                      newLeft = _dragStartRect!.right - minSize;
                      newWidth = minSize;
                    }
                    if (newHeight < minSize) newHeight = minSize;
                    newRect = Rect.fromLTWH(
                      newLeft,
                      _dragStartRect!.top,
                      newWidth,
                      newHeight,
                    );
                    break;
                  case DragHandle.bottomRight:
                    double newWidth = snapToGrid(
                      _dragStartRect!.width + deltaX,
                    );
                    double newHeight = snapToGrid(
                      _dragStartRect!.height + deltaY,
                    );
                    if (newWidth < minSize) newWidth = minSize;
                    if (newHeight < minSize) newHeight = minSize;
                    newRect = Rect.fromLTWH(
                      _dragStartRect!.left,
                      _dragStartRect!.top,
                      newWidth,
                      newHeight,
                    );
                    break;
                  case DragHandle.top:
                    double newTop = snapToGrid(_dragStartRect!.top + deltaY);
                    double newHeight = _dragStartRect!.bottom - newTop;
                    if (newHeight < minSize) {
                      newTop = _dragStartRect!.bottom - minSize;
                      newHeight = minSize;
                    }
                    newRect = Rect.fromLTWH(
                      _dragStartRect!.left,
                      newTop,
                      _dragStartRect!.width,
                      newHeight,
                    );
                    break;
                  case DragHandle.bottom:
                    double newHeight = snapToGrid(
                      _dragStartRect!.height + deltaY,
                    );
                    if (newHeight < minSize) newHeight = minSize;
                    newRect = Rect.fromLTWH(
                      _dragStartRect!.left,
                      _dragStartRect!.top,
                      _dragStartRect!.width,
                      newHeight,
                    );
                    break;
                  case DragHandle.left:
                    double newLeft = snapToGrid(_dragStartRect!.left + deltaX);
                    double newWidth = _dragStartRect!.right - newLeft;
                    if (newWidth < minSize) {
                      newLeft = _dragStartRect!.right - minSize;
                      newWidth = minSize;
                    }
                    newRect = Rect.fromLTWH(
                      newLeft,
                      _dragStartRect!.top,
                      newWidth,
                      _dragStartRect!.height,
                    );
                    break;
                  case DragHandle.right:
                    double newWidth = snapToGrid(
                      _dragStartRect!.width + deltaX,
                    );
                    if (newWidth < minSize) newWidth = minSize;
                    newRect = Rect.fromLTWH(
                      _dragStartRect!.left,
                      _dragStartRect!.top,
                      newWidth,
                      _dragStartRect!.height,
                    );
                    break;
                  case DragHandle.center:
                    double newLeft = snapToGrid(_dragStartRect!.left + deltaX);
                    double newTop = snapToGrid(_dragStartRect!.top + deltaY);
                    newLeft = newLeft.clamp(0.0, 1.0 - _dragStartRect!.width);
                    newTop = newTop.clamp(0.0, 1.0 - _dragStartRect!.height);
                    newRect = Rect.fromLTWH(
                      newLeft,
                      newTop,
                      _dragStartRect!.width,
                      _dragStartRect!.height,
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
                ref.read(isDraggingCanvasProvider.notifier).state = false;
              },
              onPanCancel: () {
                _activeHandle = DragHandle.none;
                ref.read(isDraggingCanvasProvider.notifier).state = false;
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
        final compColor = PixelArtComponent.getColor(i).withValues(alpha: 0.4);
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
          final activeColor = PixelArtComponent.getColor(
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
