import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

Color getComponentColor(int index) {
  final colors = [
    Colors.blue,
    Colors.amber,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.orange,
  ];
  return colors[index % colors.length].withValues(alpha: 0.8);
}

class ComponentConfirmationDialog extends ConsumerWidget {
  final int componentIndex;
  final PixelArtComponent component;

  const ComponentConfirmationDialog({
    super.key,
    required this.componentIndex,
    required this.component,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasStateProvider);

    return AlertDialog(
      key: const ValueKey('component_confirmation_dialog'),
      title: Text('Approve "${component.name}"?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'The evaluator thinks the sketch for "${component.name}" is finished.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: ComponentPreviewCanvas(
              grid:
                  component.getOutlineGrid() ??
                  component.grid ??
                  List.generate(
                    canvasState.gridSize,
                    (_) => List.filled(canvasState.gridSize, 0),
                  ),
              color: getComponentColor(componentIndex),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Description: ${component.description}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Do you want to approve this sketch or keep iterating?',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('keep_iterating_button'),
          onPressed: () {
            ref.read(canvasStateProvider.notifier).respondToConfirmation(false);
            Navigator.of(context).pop();
          },
          child: const Text('No, keep iterating'),
        ),
        ElevatedButton(
          key: const ValueKey('approve_component_button'),
          onPressed: () {
            ref.read(canvasStateProvider.notifier).respondToConfirmation(true);
            Navigator.of(context).pop();
          },
          child: const Text('Yes, looks good'),
        ),
      ],
    );
  }
}

class ComponentPreviewCanvas extends StatelessWidget {
  final List<List<int>> grid;
  final Color color;
  final double size;

  const ComponentPreviewCanvas({
    super.key,
    required this.grid,
    required this.color,
    this.size = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: MiniCanvasPainter(grid: grid, color: color),
        ),
      ),
    );
  }
}

class MiniCanvasPainter extends CustomPainter {
  final List<List<int>> grid;
  final Color color;

  MiniCanvasPainter({required this.grid, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = grid.length;
    if (gridSize == 0) return;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    // Draw solid background
    final bgBasePaint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgBasePaint);

    // Draw checkerboard
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
        final paint = (x + y) % 2 == 0 ? bgPaint1 : bgPaint2;
        canvas.drawRect(rect, paint);
      }
    }

    // Draw outline/grid pixels
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (y < grid.length && x < grid[y].length && grid[y][x] > 0) {
          final rect = Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth,
            cellHeight,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MiniCanvasPainter oldDelegate) {
    return oldDelegate.grid != grid || oldDelegate.color != color;
  }
}
