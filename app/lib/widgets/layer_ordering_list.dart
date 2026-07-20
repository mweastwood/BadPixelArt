import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'wizard_controls.dart';

class LayerOrderingList extends ConsumerWidget {
  final bool initialCollapsed;

  const LayerOrderingList({super.key, this.initialCollapsed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);
    final components = canvasState.decomposedComponents;

    if (components.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No components available. Please sketch and sculpt components first.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            'Step 6: Define Layer Order',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drag layers or use arrow buttons to change their drawing order. Layers at the bottom of this list are drawn last (placed on top of layers above them).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: components.length,
            // ignore: deprecated_member_use
            onReorder: notifier.reorderComponents,
            itemBuilder: (context, index) {
              final comp = components[index];
              final isActive = index == canvasState.activeComponentIndex;

              return Theme(
                key: ValueKey(comp.name),
                data: theme.copyWith(canvasColor: Colors.transparent),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    onTap: () => notifier.selectComponent(index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.8)
                            : theme.colorScheme.surfaceContainerHigh.withValues(
                                alpha: 0.4,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary.withValues(alpha: 0.8)
                              : theme.colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                          width: isActive ? 2.0 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_indicator,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'Layer ${index + 1}: ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                comp.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              if (comp.fillColor != null) ...[
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: comp.fillColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Filled',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (comp.outlineColor != null) ...[
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: comp.outlineColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Outlined',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              onPressed: index > 0
                                  ? () => notifier.reorderComponents(
                                      index,
                                      index - 1,
                                    )
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              onPressed: index < components.length - 1
                                  ? () => notifier.reorderComponents(
                                      index,
                                      index + 2,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
          icon: const Icon(Icons.layers_outlined),
          label: const Text(
            'Merge Layers to Canvas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: canvasState.isGenerating
              ? null
              : () {
                  notifier.mergeComponentsToCanvas();
                  ref
                      .read(wizardStateProvider.notifier)
                      .setStep(WizardStep.refinement);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Merged layers to canvas & entered Refinement!',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
        ),
      ],
    );
  }
}
