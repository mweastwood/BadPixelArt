import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class ShapeDecompositionList extends ConsumerStatefulWidget {
  final bool initialCollapsed;

  const ShapeDecompositionList({super.key, this.initialCollapsed = false});

  @override
  ConsumerState<ShapeDecompositionList> createState() =>
      _ShapeDecompositionListState();
}

class _ShapeDecompositionListState
    extends ConsumerState<ShapeDecompositionList> {
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initialCollapsed;
  }

  @override
  Widget build(BuildContext context) {
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
            // Header Row (Tappable to expand/collapse)
            InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Shape Decomposition',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isCollapsed && components.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${components.length} parts',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      _isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            if (!_isCollapsed) ...[
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
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: components.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final comp = components[index];
                    final isActive = index == activeIndex;

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
                            // BBox icon indicator
                            Icon(
                              Icons.crop_free_outlined,
                              size: 18,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
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
                                  if (comp.shapes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: comp.shapes.map((shape) {
                                        IconData icon;
                                        switch (shape.type) {
                                          case 'circle':
                                            icon = Icons.circle;
                                            break;
                                          case 'triangle':
                                            icon = Icons.change_history;
                                            break;
                                          case 'rectangle':
                                          default:
                                            icon = Icons.crop_square;
                                            break;
                                        }
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainer,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: theme
                                                  .colorScheme
                                                  .outlineVariant,
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                icon,
                                                size: 10,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                shape.description,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontSize: 9,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Bounding Box summary
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'BBox',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '[${(comp.relativeBoundingBox.left * 100).round()}%, ${(comp.relativeBoundingBox.top * 100).round()}%]',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Decompose Button
                            IconButton(
                              icon: canvasModel.isGenerating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      comp.shapes.isEmpty
                                          ? Icons.auto_awesome_outlined
                                          : Icons.refresh_outlined,
                                      size: 20,
                                    ),
                              tooltip: comp.shapes.isEmpty
                                  ? 'Decompose into Shapes'
                                  : 'Re-decompose into Shapes',
                              onPressed: canvasModel.isGenerating
                                  ? null
                                  : () => notifier.decomposeComponentToShapes(
                                      index,
                                    ),
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
