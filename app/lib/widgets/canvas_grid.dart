import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/agents/base_agent.dart';

class CanvasGrid extends ConsumerWidget {
  const CanvasGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasModel = ref.watch(canvasStateProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Find the maximum square size that fits
        final size = min(constraints.maxWidth, constraints.maxHeight);

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
                child: CustomPaint(
                  painter: CanvasPainter(
                    grid: canvasModel.grid,
                    palette: canvasModel.palette,
                    decomposedComponents: canvasModel.decomposedComponents,
                    activeComponentIndex: canvasModel.activeComponentIndex,
                  ),
                  child: GridPaper(
                    color: Colors.grey[800]!.withValues(alpha: 0.2),
                    divisions: 1,
                    subdivisions: 1,
                    interval:
                        size / canvasModel.gridSize, // Visual helper gridlines
                    child: Container(),
                  ),
                ),
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

  CanvasPainter({
    required this.grid,
    required this.palette,
    required this.decomposedComponents,
    required this.activeComponentIndex,
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
        oldDelegate.activeComponentIndex != activeComponentIndex;
  }
}
