import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/agents/shape_sculpter_agent.dart';
import 'wizard_controls.dart';
import 'canvas/canvas_painter.dart';
export 'canvas/canvas_painter.dart';

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
    final isSketchingPlanPhase =
        wizardState.currentStep == WizardStep.sketchingPlan;
    final isSculptingPhase =
        wizardState.currentStep == WizardStep.componentSculpting;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - 56.0
            : constraints.maxWidth;
        final size = max(0.0, min(constraints.maxWidth, availableHeight));

        Widget gridContent = CustomPaint(
          painter: CanvasPainter(
            grid: canvasModel.grid,
            palette: canvasModel.palette,
            decomposedComponents: canvasModel.decomposedComponents,
            activeComponentIndex: canvasModel.activeComponentIndex,
            currentStep: wizardState.currentStep,
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

        final scaleMode = ref.watch(canvasScaleModeProvider);

        Widget cardBody;
        switch (scaleMode) {
          case CanvasScaleMode.full:
            cardBody = Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                if (isSketchingPlanPhase || isSculptingPhase) {
                  ref.read(isDraggingCanvasProvider.notifier).state = true;
                }
              },
              onPointerUp: (_) {
                ref.read(isDraggingCanvasProvider.notifier).state = false;
              },
              onPointerCancel: (_) {
                ref.read(isDraggingCanvasProvider.notifier).state = false;
              },
              child: gridContent,
            );
            break;
          case CanvasScaleMode.scaled1x:
            cardBody = ScaledCanvasPreview(
              grid: canvasModel.grid,
              palette: canvasModel.palette,
              scaleFactor: 1.0,
              label: '1x True Scale',
            );
            break;
          case CanvasScaleMode.scaled4x:
            cardBody = ScaledCanvasPreview(
              grid: canvasModel.grid,
              palette: canvasModel.palette,
              scaleFactor: 4.0,
              label: '4x Upscaled',
            );
            break;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Card(
                key: const ValueKey('canvas_grid_card'),
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: cardBody,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const CanvasScaleToggle(),
          ],
        );
      },
    );
  }
}

class ScaledCanvasPreview extends StatelessWidget {
  final List<List<int>> grid;
  final List<Color> palette;
  final double scaleFactor;
  final String label;

  const ScaledCanvasPreview({
    super.key,
    required this.grid,
    required this.palette,
    required this.scaleFactor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final gridSize = grid.length;
    final displayWidth = (gridSize * scaleFactor).toDouble();
    final displayHeight = (gridSize * scaleFactor).toDouble();
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('scaled_canvas_preview'),
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF161616),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: displayWidth,
              height: displayHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: CustomPaint(
                size: Size(displayWidth, displayHeight),
                painter: MiniPixelPainter(grid: grid, palette: palette),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$label (${displayWidth.toInt()}×${displayHeight.toInt()}px)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniPixelPainter extends CustomPainter {
  final List<List<int>> grid;
  final List<Color> palette;

  MiniPixelPainter({required this.grid, required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = grid.length;
    if (gridSize == 0) return;
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    // Checkerboard background
    final bgPaint1 = Paint()
      ..color = const Color(0xFF262626)
      ..isAntiAlias = false;
    final bgPaint2 = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..isAntiAlias = false;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        final bg = ((r + c) % 2 == 0) ? bgPaint1 : bgPaint2;
        canvas.drawRect(rect, bg);

        final colorIdx = grid[r][c];
        if (colorIdx > 0 && colorIdx < palette.length) {
          final p = Paint()
            ..color = palette[colorIdx]
            ..isAntiAlias = false;
          canvas.drawRect(rect, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MiniPixelPainter oldDelegate) {
    return oldDelegate.grid != grid || oldDelegate.palette != palette;
  }
}

class CanvasScaleToggle extends ConsumerWidget {
  const CanvasScaleToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaleMode = ref.watch(canvasScaleModeProvider);
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('canvas_scale_toggle'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SegmentedButton<CanvasScaleMode>(
        segments: const [
          ButtonSegment<CanvasScaleMode>(
            value: CanvasScaleMode.full,
            label: Text('Full'),
            icon: Icon(Icons.aspect_ratio),
          ),
          ButtonSegment<CanvasScaleMode>(
            value: CanvasScaleMode.scaled1x,
            label: Text('1x'),
            icon: Icon(Icons.crop_original),
          ),
          ButtonSegment<CanvasScaleMode>(
            value: CanvasScaleMode.scaled4x,
            label: Text('4x'),
            icon: Icon(Icons.zoom_in),
          ),
        ],
        selected: {scaleMode},
        onSelectionChanged: (newSelection) {
          ref.read(canvasScaleModeProvider.notifier).state = newSelection.first;
        },
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
