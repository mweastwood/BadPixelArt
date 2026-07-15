import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'package:local_agent/local_agent.dart';
import '../widgets/canvas_grid.dart';
import '../widgets/color_palette_generator.dart';
import '../widgets/ai_history_dock.dart';
import '../widgets/resolution_selector_dialog.dart';
import '../widgets/model_options_dialog.dart';
import '../widgets/reference_image_prompt.dart';
import '../widgets/decomposed_components_list.dart';

class PixelArtScreen extends ConsumerWidget {
  const PixelArtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    ref.listen<
      int?
    >(canvasStateProvider.select((s) => s.confirmingComponentIndex), (
      previous,
      next,
    ) {
      if (next != null) {
        final comp = ref.read(canvasStateProvider).decomposedComponents[next];
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.15),
          builder: (context) => AlertDialog(
            alignment: Alignment.bottomCenter,
            key: const ValueKey('component_confirmation_dialog'),
            title: Text('Approve "${comp.name}"?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The evaluator thinks the sketch for "${comp.name}" is finished.',
                ),
                const SizedBox(height: 8),
                Text('Description: ${comp.description}'),
                const SizedBox(height: 12),
                const Text(
                  'Do you want to approve this sketch or keep iterating?',
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const ValueKey('keep_iterating_button'),
                onPressed: () {
                  ref
                      .read(canvasStateProvider.notifier)
                      .respondToConfirmation(false);
                  Navigator.of(context).pop();
                },
                child: const Text('No, keep iterating'),
              ),
              ElevatedButton(
                key: const ValueKey('approve_component_button'),
                onPressed: () {
                  ref
                      .read(canvasStateProvider.notifier)
                      .respondToConfirmation(true);
                  Navigator.of(context).pop();
                },
                child: const Text('Yes, looks good'),
              ),
            ],
          ),
        );
      }
    });

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Bad Pixel Art'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 8.0,
                ),
                child: _buildStatusChip(canvasState.aiStatus, notifier, theme),
              ),
              IconButton(
                key: const ValueKey('grid_size_button'),
                icon: const Icon(Icons.grid_on),
                tooltip: 'Select Grid Size',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ResolutionSelectorDialog(
                      currentGridSize: canvasState.gridSize,
                      onSelected: (size) {
                        notifier.changeResolution(size);
                      },
                    ),
                  );
                },
              ),
              IconButton(
                key: const ValueKey('model_options_button'),
                icon: const Icon(Icons.settings),
                tooltip: 'Model Options',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ModelOptionsDialog(
                      currentReleaseStage: canvasState.modelReleaseStage,
                      currentPreference: canvasState.modelPreference,
                      onChanged: (stage, preference) {
                        notifier.setModelConfig(stage, preference);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > 800;

              if (isLandscape) {
                // Desktop/Tablet Split Layout
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left side: Just the Canvas
                      const Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: CanvasGrid()),
                            SizedBox(height: 16),
                            _CanvasControlsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right side: Controls (Palette & AI)
                      const Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ReferenceImagePrompt(),
                              SizedBox(height: 16),
                              DecomposedComponentsList(),
                              SizedBox(height: 16),
                              ColorPaletteGenerator(),
                              SizedBox(height: 16),
                              AiHistoryDock(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // Mobile Portrait Layout
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 380, child: CanvasGrid()),
                      const SizedBox(height: 16),
                      const _CanvasControlsCard(),
                      const SizedBox(height: 16),
                      const ReferenceImagePrompt(),
                      const SizedBox(height: 16),
                      const DecomposedComponentsList(),
                      const SizedBox(height: 16),
                      const ColorPaletteGenerator(),
                      const SizedBox(height: 16),
                      const AiHistoryDock(),
                    ],
                  ),
                );
              }
            },
          ),
        ),
        if (canvasState.isSuggestingPalette)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                color: theme.colorScheme.surface,
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value:
                            (!kIsWeb &&
                                Platform.environment.containsKey(
                                  'FLUTTER_TEST',
                                ))
                            ? 0.5
                            : null,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'AI is generating a custom 16-color palette...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (canvasState.showPaletteSuggestion &&
            canvasState.suggestedPalette != null)
          Container(
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: canvasState.suggestedPalette!.length,
                        itemBuilder: (context, index) {
                          final color = canvasState.suggestedPalette![index];
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
                            onPressed: () =>
                                notifier.suggestPaletteFromReference(),
                            child: const Text('Retry'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => notifier.rejectSuggestedPalette(),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => notifier.acceptSuggestedPalette(),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(
    AiCoreStatus status,
    CanvasNotifier notifier,
    ThemeData theme,
  ) {
    Color color;
    String label;
    VoidCallback? onTap;

    switch (status) {
      case AiCoreStatus.available:
        color = Colors.green;
        label = 'Ready';
        break;
      case AiCoreStatus.downloadable:
        color = Colors.blue;
        label = 'Download Model';
        onTap = notifier.triggerDownload;
        break;
      case AiCoreStatus.downloading:
        color = Colors.orange;
        label = 'Downloading...';
        break;
      case AiCoreStatus.unavailable:
        color = Colors.red;
        label = 'Unavailable';
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasControlsCard extends ConsumerWidget {
  const _CanvasControlsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Left-aligned AI Controls
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: canvasModel.isGenerating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.psychology, size: 18),
                  label: Text(
                    canvasModel.isGenerating
                        ? 'AI Drawing...'
                        : 'Suggest Stroke',
                  ),
                  onPressed:
                      canvasModel.isGenerating ||
                          canvasModel.aiStatus != AiCoreStatus.available
                      ? null
                      : notifier.triggerAiStroke,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: canvasModel.autoRun
                      ? 'Pause Auto-Run'
                      : 'Start Auto-Run',
                  icon: Icon(
                    canvasModel.autoRun ? Icons.pause : Icons.play_arrow,
                    color: canvasModel.autoRun ? Colors.amber : Colors.green,
                    size: 24,
                  ),
                  onPressed: canvasModel.aiStatus == AiCoreStatus.available
                      ? notifier.toggleAutoRun
                      : null,
                ),
                const Spacer(),
                // Right-aligned Canvas Actions
                IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo),
                  onPressed: canvasModel.undoStack.isNotEmpty
                      ? notifier.undo
                      : null,
                ),
                IconButton(
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo),
                  onPressed: canvasModel.redoStack.isNotEmpty
                      ? notifier.redo
                      : null,
                ),
                IconButton(
                  tooltip: 'Reset Canvas',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: notifier.resetCanvas,
                ),
              ],
            ),
            if (canvasModel.autoRun) ...[
              const SizedBox(height: 8),
              const Divider(),
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Speed:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      value: canvasModel.autoRunSpeed,
                      label: '${canvasModel.autoRunSpeed}s',
                      onChanged: notifier.updateSpeed,
                    ),
                  ),
                  Text(
                    '${canvasModel.autoRunSpeed}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
