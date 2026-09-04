import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/canvas_state.dart';
import '../logic/agents/shape_sculpter_agent.dart';
import '../logic/controllers/component_bounding_box_gesture_handler.dart';
import '../logic/models/drag_handle.dart';
export '../logic/models/drag_handle.dart';
export '../logic/models/sculpting_candidates.dart';
import '../logic/wizard_state.dart';
import 'canvas/canvas_painter.dart';
export 'canvas/canvas_painter.dart';
import 'canvas/scaled_canvas_preview.dart';
export 'canvas/scaled_canvas_preview.dart';

class CanvasGrid extends ConsumerStatefulWidget {
  const CanvasGrid({super.key});

  @override
  ConsumerState<CanvasGrid> createState() => _CanvasGridState();
}

class _CanvasGridState extends ConsumerState<CanvasGrid> {
  final _gestureHandler = const ComponentBoundingBoxGestureHandler();
  DragHandle _activeHandle = DragHandle.none;
  Offset? _dragStartLocalPos;
  Rect? _dragStartRect;

  SculptingCandidates? _cachedSculptingCandidates;
  List<List<int>>? _cachedComponentGrid;
  Rect? _cachedBoundingBox;
  int? _cachedGridSize;
  int? _cachedActiveComponentIndex;

  bool _gridEquals(List<List<int>>? a, List<List<int>>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final grid = ref.watch(canvasStateProvider.select((s) => s.grid));
    final gridSize = ref.watch(canvasStateProvider.select((s) => s.gridSize));
    final palette = ref.watch(canvasStateProvider.select((s) => s.palette));
    final decomposedComponents = ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents),
    );
    final activeComponentIndex = ref.watch(
      canvasStateProvider.select((s) => s.activeComponentIndex),
    );
    final isGenerating = ref.watch(
      canvasStateProvider.select((s) => s.isGenerating),
    );
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

        SculptingCandidates? sculptingCandidates;
        if (isSculptingPhase &&
            decomposedComponents.isNotEmpty &&
            !isGenerating &&
            activeComponentIndex >= 0 &&
            activeComponentIndex < decomposedComponents.length) {
          final comp = decomposedComponents[activeComponentIndex];
          if (comp.grid != null) {
            final bool gridChanged = !_gridEquals(
              _cachedComponentGrid,
              comp.grid,
            );
            final bool bboxChanged =
                _cachedBoundingBox != comp.relativeBoundingBox;
            final bool sizeChanged = _cachedGridSize != gridSize;
            final bool indexChanged =
                _cachedActiveComponentIndex != activeComponentIndex;

            if (_cachedSculptingCandidates == null ||
                gridChanged ||
                bboxChanged ||
                sizeChanged ||
                indexChanged) {
              _cachedSculptingCandidates = calculateSculptingCandidates(
                comp.grid!,
                gridSize,
                comp.relativeBoundingBox,
              );
              _cachedComponentGrid = comp.grid!
                  .map((r) => List<int>.from(r))
                  .toList();
              _cachedBoundingBox = comp.relativeBoundingBox;
              _cachedGridSize = gridSize;
              _cachedActiveComponentIndex = activeComponentIndex;
            }
            sculptingCandidates = _cachedSculptingCandidates;
          }
        } else {
          _cachedSculptingCandidates = null;
          _cachedComponentGrid = null;
          _cachedBoundingBox = null;
          _cachedGridSize = null;
          _cachedActiveComponentIndex = null;
        }

        Widget gridContent = CustomPaint(
          painter: CanvasPainter(
            grid: grid,
            palette: palette,
            decomposedComponents: decomposedComponents,
            activeComponentIndex: activeComponentIndex,
            currentStep: wizardState.currentStep,
            isGenerating: isGenerating,
            sculptingCandidates: sculptingCandidates,
          ),
          child: GridPaper(
            color: Colors.grey[800]!.withValues(alpha: 0.2),
            divisions: 1,
            subdivisions: 1,
            interval: size / gridSize,
            child: Container(),
          ),
        );

        if (isSketchingPlanPhase && decomposedComponents.isNotEmpty) {
          final activeIndex = activeComponentIndex;
          if (activeIndex >= 0 && activeIndex < decomposedComponents.length) {
            final activeComp = decomposedComponents[activeIndex];
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
                _activeHandle = _gestureHandler.hitTest(
                  details.localPosition,
                  rect,
                );
                if (_activeHandle != DragHandle.none) {
                  _dragStartLocalPos = details.localPosition;
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

                final newRect = _gestureHandler.applyDelta(
                  handle: _activeHandle,
                  startRect: _dragStartRect!,
                  pixelDelta: details.localPosition - _dragStartLocalPos!,
                  canvasSize: size,
                  gridSize: gridSize,
                );

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

        if (isSculptingPhase && decomposedComponents.isNotEmpty) {
          final activeIndex = activeComponentIndex;
          if (activeIndex >= 0 && activeIndex < decomposedComponents.length) {
            final activeComp = decomposedComponents[activeIndex];
            if (activeComp.grid != null) {
              gridContent = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  // Only allow if AI is not running
                  if (isGenerating) return;

                  final localPos = details.localPosition;
                  final cellWidth = size / gridSize;
                  final cellHeight = size / gridSize;
                  final col = (localPos.dx / cellWidth).floor().clamp(
                    0,
                    gridSize - 1,
                  );
                  final row = (localPos.dy / cellHeight).floor().clamp(
                    0,
                    gridSize - 1,
                  );

                  // Calculate eligible candidates
                  final candidates =
                      sculptingCandidates ??
                      _cachedSculptingCandidates ??
                      calculateSculptingCandidates(
                        activeComp.grid!,
                        gridSize,
                        activeComp.relativeBoundingBox,
                      );

                  final removeList = candidates.remove;
                  final addList = candidates.add;

                  // Check if tapped pixel is in remove candidates
                  final isRemoveCandidate = removeList.any(
                    (p) => p.x == col && p.y == row,
                  );
                  if (isRemoveCandidate) {
                    ref
                        .read(canvasStateProvider.notifier)
                        .toggleComponentPixel(activeIndex, col, row, 0);
                    return;
                  }

                  // Check if tapped pixel is in add candidates
                  final isAddCandidate = addList.any(
                    (p) => p.x == col && p.y == row,
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
              grid: grid,
              palette: palette,
              scaleFactor: 1.0,
              label: '1x True Scale',
            );
            break;
          case CanvasScaleMode.scaled4x:
            cardBody = ScaledCanvasPreview(
              grid: grid,
              palette: palette,
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
