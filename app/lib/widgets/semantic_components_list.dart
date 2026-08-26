import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../logic/canvas_state.dart';

class SemanticComponentsList extends ConsumerWidget {
  const SemanticComponentsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final components = ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents),
    );
    final activeIndex = ref.watch(
      canvasStateProvider.select((s) => s.activeComponentIndex),
    );
    final hasPromptAndRef = ref.watch(
      canvasStateProvider.select(
        (s) => s.referenceImage != null && s.userPrompt.trim().isNotEmpty,
      ),
    );
    final isGenerating = ref.watch(
      canvasStateProvider.select((s) => s.isGenerating),
    );
    final aiStatus = ref.watch(canvasStateProvider.select((s) => s.aiStatus));
    final gridSize = ref.watch(canvasStateProvider.select((s) => s.gridSize));
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

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
                    Icons.playlist_add_check_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Drawing Plan Components',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (components.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Re-generate Drawing Plan',
                      onPressed:
                          !hasPromptAndRef ||
                              isGenerating ||
                              aiStatus != AiCoreStatus.available
                          ? null
                          : notifier.triggerDecomposition,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (components.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  children: [
                    Text(
                      'No components decomposed yet. Set a prompt and upload a reference image to generate your co-creation drawing plan.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.psychology),
                      label: Text(
                        isGenerating
                            ? 'Generating Plan...'
                            : 'Generate Drawing Plan',
                      ),
                      onPressed:
                          !hasPromptAndRef ||
                              isGenerating ||
                              aiStatus != AiCoreStatus.available
                          ? null
                          : notifier.triggerDecomposition,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: components.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final comp = components[index];
                  final isActive = index == activeIndex;

                  final bounds = comp.gridBounds(gridSize);
                  final minX = bounds.minX;
                  final minY = bounds.minY;
                  final maxX = bounds.maxX;
                  final maxY = bounds.maxY;

                  return InkWell(
                    onTap: () => notifier.selectComponent(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Bounding Box summary in Pixel Coordinates
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
                                '[X: $minX..$maxX, Y: $minY..$maxY]',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          // Delete Component Button
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Delete Component',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => notifier.deleteComponent(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
