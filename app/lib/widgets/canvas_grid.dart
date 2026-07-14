import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

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

  CanvasPainter({required this.grid, required this.palette});

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
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.grid != grid || oldDelegate.palette != palette;
  }
}
