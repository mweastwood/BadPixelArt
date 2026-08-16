import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/canvas_state.dart';

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
        if (colorIdx > 0 && colorIdx <= palette.length) {
          final p = Paint()
            ..color = palette[colorIdx - 1]
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
