import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../logic/models/pixel_art_component.dart';
import '../../logic/wizard_state.dart';

class CanvasPainter extends CustomPainter {
  final List<List<int>> grid;
  final List<Color> palette;
  final List<PixelArtComponent> decomposedComponents;
  final int activeComponentIndex;
  final WizardStep currentStep;
  final bool isGenerating;
  final Map<String, List<Map<String, int>>>? sculptingCandidates;

  CanvasPainter({
    required this.grid,
    required this.palette,
    required this.decomposedComponents,
    required this.activeComponentIndex,
    required this.currentStep,
    required this.isGenerating,
    this.sculptingCandidates,
  });

  bool get isSketchingPlanPhase => currentStep == WizardStep.sketchingPlan;
  bool get isSculptingPhase => currentStep == WizardStep.componentSculpting;
  bool get isColorAndOutlinePhase =>
      currentStep == WizardStep.colorAndOutline ||
      currentStep == WizardStep.layerOrderingAndMerge;

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

    if (isColorAndOutlinePhase) {
      // Draw background checkerboard for all cells
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          final rect = Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth,
            cellHeight,
          );
          final paint = (x + y) % 2 == 0 ? bgPaint1 : bgPaint2;
          canvas.drawRect(rect, paint);
        }
      }

      final fillPaint = Paint()..isAntiAlias = false;

      // Draw component fills
      for (int i = 0; i < decomposedComponents.length; i++) {
        final comp = decomposedComponents[i];
        if (comp.grid != null) {
          final isSelected = (i == activeComponentIndex);
          if (comp.fillColor != null) {
            for (int y = 0; y < gridSize; y++) {
              for (int x = 0; x < gridSize; x++) {
                if (comp.grid![y][x] > 0) {
                  final pixelCol = comp.getPixelFillColor(x, y);
                  if (pixelCol != null) {
                    fillPaint.color = pixelCol;
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
          } else {
            fillPaint.color = PixelArtComponent.getColor(
              i,
            ).withValues(alpha: isSelected ? 0.25 : 0.1);
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

      final outlinePaint = Paint()..isAntiAlias = false;

      // Draw component outlines
      for (int i = 0; i < decomposedComponents.length; i++) {
        final comp = decomposedComponents[i];
        final outline = comp.outlineGrid;
        if (outline != null) {
          final isSelected = (i == activeComponentIndex);
          final Color outlineCol =
              comp.outlineColor ??
              PixelArtComponent.getColor(
                i,
              ).withValues(alpha: isSelected ? 0.7 : 0.35);
          outlinePaint.color = outlineCol;
          for (int y = 0; y < gridSize; y++) {
            for (int x = 0; x < gridSize; x++) {
              if (outline[y][x] > 0) {
                final rect = Rect.fromLTWH(
                  x * cellWidth,
                  y * cellHeight,
                  cellWidth,
                  cellHeight,
                );
                canvas.drawRect(rect, outlinePaint);
              }
            }
          }
        }
      }
    } else {
      final cellPaint = Paint()..isAntiAlias = false;
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          final rect = Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth,
            cellHeight,
          );
          final colorIndex = grid[y][x];

          if (colorIndex > 0 && colorIndex <= palette.length) {
            cellPaint.color = palette[colorIndex - 1];
            canvas.drawRect(rect, cellPaint);
          } else {
            final paint = (x + y) % 2 == 0 ? bgPaint1 : bgPaint2;
            canvas.drawRect(rect, paint);
          }
        }
      }

      // Draw the individual component grids (outlines) as semi-transparent overlays
      if (currentStep != WizardStep.refinement) {
        final overlayPaint = Paint()..isAntiAlias = false;
        for (int i = 0; i < decomposedComponents.length; i++) {
          final comp = decomposedComponents[i];
          final compOutline = comp.outlineGrid;
          if (compOutline != null) {
            final compColor = PixelArtComponent.getColor(
              i,
            ).withValues(alpha: 0.4);
            overlayPaint.color = compColor;

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
    if (isSculptingPhase &&
        decomposedComponents.isNotEmpty &&
        !isGenerating &&
        sculptingCandidates != null) {
      final removeList = sculptingCandidates!['remove'] ?? [];
      final addList = sculptingCandidates!['add'] ?? [];

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

    // Draw component bounding boxes if present
    if (decomposedComponents.isNotEmpty &&
        currentStep != WizardStep.refinement) {
      final borderPaint = Paint()..style = PaintingStyle.stroke;
      final labelBgPaint = Paint();
      final shapePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.amberAccent;
      final handlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final handleBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

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

          labelBgPaint.color = activeColor;
          final maxLeft = max(0.0, size.width - textPainter.width);
          final maxTop = max(0.0, size.height - textPainter.height);
          final labelRect = Rect.fromLTWH(
            rect.left.clamp(0.0, maxLeft),
            (rect.top - 14.0).clamp(0.0, maxTop),
            textPainter.width,
            14.0,
          );
          canvas.drawRect(labelRect, labelBgPaint);

          textPainter.paint(canvas, Offset(labelRect.left, labelRect.top));

          // Draw the shapes inside this active component
          if (comp.shapes.isNotEmpty) {
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
            handleBorderPaint.color = activeColor;

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
    return !_gridEquals(oldDelegate.grid, grid) ||
        !listEquals(oldDelegate.palette, palette) ||
        !listEquals(oldDelegate.decomposedComponents, decomposedComponents) ||
        oldDelegate.activeComponentIndex != activeComponentIndex ||
        oldDelegate.currentStep != currentStep ||
        oldDelegate.isGenerating != isGenerating ||
        oldDelegate.sculptingCandidates != sculptingCandidates;
  }
}

bool _gridEquals(List<List<int>>? a, List<List<int>>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (!listEquals(a[i], b[i])) return false;
  }
  return true;
}
