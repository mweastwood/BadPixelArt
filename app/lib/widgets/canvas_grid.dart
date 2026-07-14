import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class CanvasGrid extends ConsumerStatefulWidget {
  const CanvasGrid({super.key});

  @override
  ConsumerState<CanvasGrid> createState() => _CanvasGridState();
}

class _CanvasGridState extends ConsumerState<CanvasGrid> {
  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  Widget build(BuildContext context) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);

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
                child: GestureDetector(
                  onPanStart: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPos = renderBox.globalToLocal(
                      details.globalPosition,
                    );
                    setState(() {
                      _dragStart = localPos;
                      _dragCurrent = localPos;
                    });
                  },
                  onPanUpdate: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPos = renderBox.globalToLocal(
                      details.globalPosition,
                    );
                    setState(() {
                      _dragCurrent = localPos;
                    });
                  },
                  onPanEnd: (details) {
                    if (_dragStart == null || _dragCurrent == null) return;

                    final gridSize = canvasModel.gridSize;
                    final cellWidth = size / gridSize;
                    final cellHeight = size / gridSize;

                    final startX = (_dragStart!.dx / cellWidth).floor().clamp(
                      0,
                      gridSize - 1,
                    );
                    final startY = (_dragStart!.dy / cellHeight).floor().clamp(
                      0,
                      gridSize - 1,
                    );
                    final currX = (_dragCurrent!.dx / cellWidth).floor().clamp(
                      0,
                      gridSize - 1,
                    );
                    final currY = (_dragCurrent!.dy / cellHeight).floor().clamp(
                      0,
                      gridSize - 1,
                    );

                    switch (canvasModel.selectedTool) {
                      case CanvasTool.line:
                        notifier.applyLine(startX, startY, currX, currY);
                        break;
                      case CanvasTool.circle:
                        final dx = currX - startX;
                        final dy = currY - startY;
                        final r = sqrt(
                          dx * dx + dy * dy,
                        ).toInt().clamp(1, gridSize - 1);
                        notifier.applyCircle(startX, startY, r);
                        break;
                      case CanvasTool.fill:
                        notifier.applyFill(startX, startY);
                        break;
                      case CanvasTool.hatch:
                        notifier.applyHatch(startX, startY);
                        break;
                    }

                    setState(() {
                      _dragStart = null;
                      _dragCurrent = null;
                    });
                  },
                  child: CustomPaint(
                    painter: CanvasPainter(
                      grid: canvasModel.grid,
                      palette: canvasModel.palette,
                      dragStart: _dragStart,
                      dragCurrent: _dragCurrent,
                      activeTool: canvasModel.selectedTool,
                      activeColorIndex: canvasModel.selectedColorIndex,
                    ),
                    child: GridPaper(
                      color: Colors.grey[800]!.withValues(alpha: 0.2),
                      divisions: 1,
                      subdivisions: 1,
                      interval:
                          size /
                          canvasModel.gridSize, // Visual helper gridlines
                      child: Container(),
                    ),
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
  final Offset? dragStart;
  final Offset? dragCurrent;
  final CanvasTool? activeTool;
  final int activeColorIndex;

  CanvasPainter({
    required this.grid,
    required this.palette,
    this.dragStart,
    this.dragCurrent,
    this.activeTool,
    required this.activeColorIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = grid.length;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    // Draw solid background to prevent subpixel outline bleeding from the Card background
    final bgBasePaint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgBasePaint);

    // Draw background grid pixels
    // We treat 0 as transparent and draw a checkerboard transparent background
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
          // Draw transparent checkerboard background
          final paint = (x + y) % 2 == 0 ? bgPaint1 : bgPaint2;
          canvas.drawRect(rect, paint);
        } else {
          // Draw painted pixel
          final paint = Paint()
            ..color = palette[colorIndex - 1]
            ..isAntiAlias = false;
          canvas.drawRect(rect, paint);
        }
      }
    }

    // Draw preview if dragging
    if (dragStart != null && dragCurrent != null && activeTool != null) {
      final startX = (dragStart!.dx / cellWidth).floor().clamp(0, gridSize - 1);
      final startY = (dragStart!.dy / cellHeight).floor().clamp(
        0,
        gridSize - 1,
      );
      final currX = (dragCurrent!.dx / cellWidth).floor().clamp(
        0,
        gridSize - 1,
      );
      final currY = (dragCurrent!.dy / cellHeight).floor().clamp(
        0,
        gridSize - 1,
      );

      final previewPaint = Paint()
        ..color = activeColorIndex == 0
            ? Colors.redAccent.withValues(alpha: 0.5)
            : palette[activeColorIndex - 1].withValues(alpha: 0.5)
        ..style = PaintingStyle.fill
        ..isAntiAlias = false;

      if (activeTool == CanvasTool.line) {
        final points = _getLinePoints(startX, startY, currX, currY);
        for (final p in points) {
          canvas.drawRect(
            Rect.fromLTWH(
              p.dx * cellWidth,
              p.dy * cellHeight,
              cellWidth,
              cellHeight,
            ),
            previewPaint,
          );
        }
      } else if (activeTool == CanvasTool.circle) {
        final dx = currX - startX;
        final dy = currY - startY;
        final r = sqrt(dx * dx + dy * dy).toInt().clamp(1, gridSize - 1);
        final points = _getCirclePoints(startX, startY, r, gridSize);
        for (final p in points) {
          canvas.drawRect(
            Rect.fromLTWH(
              p.dx * cellWidth,
              p.dy * cellHeight,
              cellWidth,
              cellHeight,
            ),
            previewPaint,
          );
        }
      } else if (activeTool == CanvasTool.fill ||
          activeTool == CanvasTool.hatch) {
        // Draw single preview pixel where drag started
        canvas.drawRect(
          Rect.fromLTWH(
            startX * cellWidth,
            startY * cellHeight,
            cellWidth,
            cellHeight,
          ),
          previewPaint,
        );
      }
    }
  }

  List<Offset> _getLinePoints(int x1, int y1, int x2, int y2) {
    List<Offset> points = [];
    int dx = (x2 - x1).abs();
    int dy = (y2 - y1).abs();
    int sx = x1 < x2 ? 1 : -1;
    int sy = y1 < y2 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      points.add(Offset(x1.toDouble(), y1.toDouble()));
      if (x1 == x2 && y1 == y2) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x1 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y1 += sy;
      }
    }
    return points;
  }

  List<Offset> _getCirclePoints(int xc, int yc, int r, int gridSize) {
    List<Offset> points = [];
    int x = 0;
    int y = r;
    int d = 3 - 2 * r;

    void addPoints(int xc, int yc, int x, int y) {
      void add(int px, int py) {
        if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
          points.add(Offset(px.toDouble(), py.toDouble()));
        }
      }

      add(xc + x, yc + y);
      add(xc - x, yc + y);
      add(xc + x, yc - y);
      add(xc - x, yc - y);
      add(xc + y, yc + x);
      add(xc - y, yc + x);
      add(xc + y, yc - x);
      add(xc - y, yc - x);
    }

    addPoints(xc, yc, x, y);
    while (y >= x) {
      x++;
      if (d > 0) {
        y--;
        d = d + 4 * (x - y) + 10;
      } else {
        d = d + 4 * x + 6;
      }
      addPoints(xc, yc, x, y);
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.palette != palette ||
        oldDelegate.dragStart != dragStart ||
        oldDelegate.dragCurrent != dragCurrent ||
        oldDelegate.activeTool != activeTool ||
        oldDelegate.activeColorIndex != activeColorIndex;
  }
}
