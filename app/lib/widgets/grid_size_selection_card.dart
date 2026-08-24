import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/wizard_state.dart';

class GridSizeSelectionCard extends ConsumerWidget {
  const GridSizeSelectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gridSize = ref.watch(canvasStateProvider.select((s) => s.gridSize));
    final wizardMode = ref.watch(wizardStateProvider.select((s) => s.mode));
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.grid_on, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Canvas Resolution',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select the pixel grid resolution for your canvas. Changing resolution will reset the canvas.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSizeTile(
                    context,
                    notifier,
                    8,
                    '8 x 8',
                    gridSize == 8,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSizeTile(
                    context,
                    notifier,
                    16,
                    '16 x 16',
                    gridSize == 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Wizard Mode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose between structured step-by-step layer decomposition or direct freeform AI painting.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<WizardMode>(
              key: const ValueKey('wizard_mode_selector'),
              segments: const [
                ButtonSegment<WizardMode>(
                  value: WizardMode.structured,
                  label: Text('Structured'),
                  icon: Icon(Icons.account_tree_outlined),
                ),
                ButtonSegment<WizardMode>(
                  value: WizardMode.direct,
                  label: Text('Direct Paint'),
                  icon: Icon(Icons.brush_outlined),
                ),
              ],
              selected: {wizardMode},
              onSelectionChanged: (newSelection) {
                ref
                    .read(wizardStateProvider.notifier)
                    .setMode(newSelection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeTile(
    BuildContext context,
    CanvasNotifier notifier,
    int size,
    String label,
    bool isSelected,
  ) {
    final theme = Theme.of(context);

    return Card(
      key: ValueKey('grid_size_card_$size'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      elevation: isSelected ? 2 : 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => notifier.changeResolution(size),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_on,
                size: size == 8 ? 28 : 36,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
