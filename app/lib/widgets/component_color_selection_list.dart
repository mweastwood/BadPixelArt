import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class ComponentColorSelectionList extends ConsumerWidget {
  final bool initialCollapsed;

  const ComponentColorSelectionList({super.key, this.initialCollapsed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    if (canvasState.decomposedComponents.isEmpty) {
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
            'Step 5: Pick Component Colors',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: canvasState.decomposedComponents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final comp = canvasState.decomposedComponents[index];
            final isActive = index == canvasState.activeComponentIndex;

            return GestureDetector(
              onTap: () => notifier.selectComponent(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.8,
                        )
                      : theme.colorScheme.surfaceContainer.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.8)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                    width: isActive ? 2.0 : 1.0,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Component Header
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: PixelArtComponent.getColor(index),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                      if (comp.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          comp.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Divider(height: 24, thickness: 0.5),

                      // Fill Color Row
                      _buildColorSelectorRow(
                        context: context,
                        title: 'Fill Color',
                        selectedColor: comp.fillColor,
                        palette: canvasState.palette,
                        onColorSelected: (color) {
                          notifier.updateComponentColors(
                            index,
                            color,
                            comp.outlineColor,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Outline Color Row
                      _buildColorSelectorRow(
                        context: context,
                        title: 'Outline Color',
                        selectedColor: comp.outlineColor,
                        palette: canvasState.palette,
                        onColorSelected: (color) {
                          notifier.updateComponentColors(
                            index,
                            comp.fillColor,
                            color,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
          ),
          icon: const Icon(Icons.layers_outlined),
          label: const Text(
            'Merge Components with Colors to Canvas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: canvasState.isGenerating
              ? null
              : () {
                  notifier.mergeComponentsToCanvas();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Merged components with colors to canvas!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
        ),
      ],
    );
  }

  Widget _buildColorSelectorRow({
    required BuildContext context,
    required String title,
    required Color? selectedColor,
    required List<Color> palette,
    required ValueChanged<Color?> onColorSelected,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "None" (Transparent / Clear) Selector
                GestureDetector(
                  onTap: () => onColorSelected(null),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: selectedColor == null ? 2.0 : 1.0,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.block,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                // Palette Colors Selectors
                ...palette.map((color) {
                  final isSelected =
                      selectedColor?.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => onColorSelected(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
