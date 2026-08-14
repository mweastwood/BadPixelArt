import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class CustomPaletteConfirmationDialog extends ConsumerWidget {
  final List<Color>? palette;
  final VoidCallback? onRetry;
  final VoidCallback? onReject;
  final VoidCallback? onAccept;

  const CustomPaletteConfirmationDialog({
    super.key,
    this.palette,
    this.onRetry,
    this.onReject,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final effectivePalette =
        palette ?? canvasState.suggestedPalette ?? const [];

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: theme.colorScheme.surface,
          margin: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Confirm Custom Palette',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The AI analyzed your reference image and suggested this 16-color palette:',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: effectivePalette.length,
                  itemBuilder: (context, index) {
                    final color = effectivePalette[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          onRetry ??
                          () => notifier.suggestPaletteFromReference(),
                      child: const Text('Retry'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed:
                          onReject ?? () => notifier.rejectSuggestedPalette(),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed:
                          onAccept ?? () => notifier.acceptSuggestedPalette(),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
