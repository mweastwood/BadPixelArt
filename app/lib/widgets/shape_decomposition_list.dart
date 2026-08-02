import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class ShapeDecompositionList extends ConsumerWidget {
  const ShapeDecompositionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);
    final components = canvasModel.decomposedComponents;
    final activeIndex = canvasModel.activeComponentIndex;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.brush_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Component Sculpting',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (components.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: Text(
                    'No drawing plan generated yet. Go back to generate semantic components first.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: components.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final comp = components[index];
                  final isActive = index == activeIndex;
                  final isThisDecomposing =
                      canvasModel.isGenerating &&
                      (canvasModel.decomposingComponentIndex != null
                          ? canvasModel.decomposingComponentIndex == index
                          : canvasModel.activeComponentIndex == index);

                  return InkWell(
                    onTap: () => notifier.selectComponent(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: isActive ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Mini Canvas Preview with Completion Overlay
                          if (comp.grid != null)
                            Stack(
                              children: [
                                MiniComponentCanvas(
                                  grid: comp.grid!,
                                  color: PixelArtComponent.getColor(index),
                                ),
                                if (!isThisDecomposing)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        comp.isSculpted
                                            ? Icons.check_circle_rounded
                                            : Icons.pending_rounded,
                                        key: ValueKey(
                                          comp.isSculpted
                                              ? 'sculpted_check_icon_$index'
                                              : 'sculpted_pending_icon_$index',
                                        ),
                                        size: 14,
                                        color: comp.isSculpted
                                            ? theme.colorScheme.primary
                                            : Colors.amber,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          else
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                color: theme.colorScheme.surface,
                              ),
                              child: isThisDecomposing
                                  ? Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.grid_on_outlined,
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comp.name.toUpperCase(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  comp.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (isThisDecomposing) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          canvasModel.sculptingStatus ??
                                              'Sculpting shape...',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Reset Button
                          if (comp.grid != null)
                            IconButton(
                              icon: const Icon(Icons.restart_alt, size: 20),
                              tooltip: 'Reset Sculpting',
                              onPressed: canvasModel.isGenerating
                                  ? null
                                  : () => notifier.resetComponentGrid(index),
                            ),
                          // Sculpt/Refine Button
                          IconButton(
                            icon: isThisDecomposing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    comp.grid == null
                                        ? Icons.brush_outlined
                                        : Icons.auto_awesome_outlined,
                                    size: 20,
                                  ),
                            tooltip: comp.grid == null
                                ? 'Initialize & Sculpt'
                                : 'Refine Border (Sculpt)',
                            onPressed: canvasModel.isGenerating
                                ? null
                                : () => notifier.sculptComponent(index),
                          ),
                          // Delete Component Button
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Delete Component',
                            onPressed: canvasModel.isGenerating
                                ? null
                                : () => notifier.deleteComponent(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MiniComponentCanvas extends StatelessWidget {
  final List<List<int>> grid;
  final Color color;
  final double size;

  const MiniComponentCanvas({
    super.key,
    required this.grid,
    required this.color,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(
          painter: _MiniCanvasPainter(grid: grid, color: color),
        ),
      ),
    );
  }
}

class _MiniCanvasPainter extends CustomPainter {
  final List<List<int>> grid;
  final Color color;

  _MiniCanvasPainter({required this.grid, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = grid.length;
    if (gridSize == 0) return;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    final bgPaint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (grid[y][x] > 0) {
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
  bool shouldRepaint(covariant _MiniCanvasPainter oldDelegate) {
    return oldDelegate.grid != grid || oldDelegate.color != color;
  }
}
