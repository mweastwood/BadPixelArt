import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../widgets/model_options_dialog.dart';
import '../widgets/decomposed_components_list.dart';
import '../widgets/wizard_controls.dart';
import '../widgets/ai_history_dock.dart';
import 'creations_screen.dart';
import 'canvas_screen.dart';
import 'logs_screen.dart';

class PixelArtScreen extends ConsumerStatefulWidget {
  const PixelArtScreen({super.key});

  @override
  ConsumerState<PixelArtScreen> createState() => _PixelArtScreenState();
}

class _PixelArtScreenState extends ConsumerState<PixelArtScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, initialIndex: 1, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
    if (_tabController.index != 1 && ref.read(canvasStateProvider).autoRun) {
      ref.read(canvasStateProvider.notifier).stopAutoPlay();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);
    final isDraggingCanvas = ref.watch(isDraggingCanvasProvider);
    final history = canvasState.aiHistory;

    // Global listener for decomposition option choose dialog
    ref.listen<CanvasModel>(canvasStateProvider, (previous, next) {
      if (next.pendingDecompositionOptions.isNotEmpty &&
          (previous == null || previous.pendingDecompositionOptions.isEmpty)) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => DecompositionOptionsDialog(
            options: next.pendingDecompositionOptions,
            onSelected: (optIdx) {
              ref
                  .read(canvasStateProvider.notifier)
                  .applyDecompositionOption(optIdx);
              Navigator.of(context).pop();
            },
            onCancel: () {
              ref
                  .read(canvasStateProvider.notifier)
                  .clearPendingDecompositionOptions();
              Navigator.of(context).pop();
            },
          ),
        );
      }
    });

    final double totalCost = history.fold(
      0.0,
      (sum, item) => sum + (item.estimatedCostUsd ?? 0.0),
    );

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(
                  _tabController.index == 0
                      ? 'Creations Gallery'
                      : (_tabController.index == 2
                            ? 'Conversation History'
                            : 'Bad Pixel Art'),
                ),
                const Spacer(),
                Text(
                  '${history.length} ${history.length == 1 ? 'msg' : 'msgs'} • \$${totalCost.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 8.0,
                ),
                child: _buildStatusChip(canvasState.aiStatus, notifier, theme),
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
          body: TabBarView(
            controller: _tabController,
            physics: isDraggingCanvas
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            children: [
              CreationsScreen(
                onCreationSelected: () {
                  _tabController.animateTo(1);
                },
              ),
              const CanvasScreen(),
              const LogsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabController.index,
            onDestinationSelected: (int index) {
              _tabController.animateTo(index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.collections_outlined),
                selectedIcon: Icon(Icons.collections),
                label: 'Creations',
              ),
              const NavigationDestination(
                icon: Icon(Icons.palette_outlined),
                selectedIcon: Icon(Icons.palette),
                label: 'Canvas',
              ),
              NavigationDestination(
                icon: history.isEmpty
                    ? const Icon(Icons.chat_bubble_outline)
                    : Badge(
                        label: Text('${history.length}'),
                        child: const Icon(Icons.chat_bubble_outline),
                      ),
                selectedIcon: history.isEmpty
                    ? const Icon(Icons.chat_bubble)
                    : Badge(
                        label: Text('${history.length}'),
                        child: const Icon(Icons.chat_bubble),
                      ),
                label: 'Logs',
              ),
            ],
          ),
          floatingActionButton: _tabController.index == 0
              ? FloatingActionButton(
                  key: const ValueKey('new_creation_fab'),
                  heroTag: 'new_creation_fab',
                  onPressed: () async {
                    await notifier.startNewCanvas();
                    ref.read(wizardStateProvider.notifier).reset();
                    _tabController.animateTo(1);
                  },
                  tooltip: 'New Creation',
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: const Icon(Icons.add),
                )
              : (_tabController.index == 1
                    ? _buildFloatingActionButtons(context, ref)
                    : FloatingActionButton(
                        key: const ValueKey('export_logs_fab'),
                        heroTag: 'export_logs_fab',
                        onPressed: () => exportAiHistory(context, history),
                        tooltip: 'Export Logs',
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        child: const Icon(Icons.file_download_outlined),
                      )),
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
                        'AI is generating a custom 8-color palette...',
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

Widget? _buildFloatingActionButtons(BuildContext context, WidgetRef ref) {
  final wizardState = ref.watch(wizardStateProvider);
  final canvasState = ref.watch(canvasStateProvider);
  final notifier = ref.read(canvasStateProvider.notifier);
  final theme = Theme.of(context);

  if (canvasState.isSuggestingPalette) return null;

  final hasRefImage = canvasState.referenceImage != null;
  final isAutoPlaying = canvasState.autoRun || canvasState.isPausing;

  final step = wizardState.currentStep;
  final hasBack = step.index > 0;
  final hasNext = step.index < 7;

  VoidCallback? onNext;
  if (!isAutoPlaying) {
    if (step == WizardStep.selectGridSize) {
      onNext = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.setupPrompt);
    } else if (step == WizardStep.setupPrompt) {
      final canGoToPalette = canvasState.userPrompt.trim().isNotEmpty;
      onNext = canGoToPalette
          ? () => ref
                .read(wizardStateProvider.notifier)
                .setStep(WizardStep.selectPalette)
          : null;
    } else if (step == WizardStep.selectPalette) {
      onNext = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.sketchingPlan);
    } else if (step == WizardStep.sketchingPlan) {
      onNext =
          (canvasState.isGenerating || canvasState.decomposedComponents.isEmpty)
          ? null
          : () => ref
                .read(wizardStateProvider.notifier)
                .setStep(WizardStep.componentSculpting);
    } else if (step == WizardStep.componentSculpting) {
      onNext = canvasState.decomposedComponents.isEmpty
          ? null
          : () => ref
                .read(wizardStateProvider.notifier)
                .setStep(WizardStep.colorAndOutline);
    } else if (step == WizardStep.colorAndOutline) {
      onNext = canvasState.decomposedComponents.isEmpty
          ? null
          : () => ref
                .read(wizardStateProvider.notifier)
                .setStep(WizardStep.layerOrderingAndMerge);
    } else if (step == WizardStep.layerOrderingAndMerge) {
      onNext = () {
        ref.read(canvasStateProvider.notifier).mergeComponentsToCanvas();
        ref.read(wizardStateProvider.notifier).setStep(WizardStep.refinement);
      };
    }
  }

  VoidCallback? onBack;
  if (!isAutoPlaying) {
    if (step == WizardStep.setupPrompt) {
      onBack = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.selectGridSize);
    } else if (step == WizardStep.selectPalette) {
      onBack = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.setupPrompt);
    } else if (step == WizardStep.sketchingPlan) {
      onBack = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.selectPalette);
    } else if (step == WizardStep.componentSculpting) {
      onBack = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.sketchingPlan);
    } else if (step == WizardStep.colorAndOutline) {
      onBack = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.componentSculpting);
    } else if (step == WizardStep.layerOrderingAndMerge) {
      onBack = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.colorAndOutline);
    } else if (step == WizardStep.refinement) {
      onBack = () => ref
          .read(wizardStateProvider.notifier)
          .setStep(WizardStep.layerOrderingAndMerge);
    }
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (hasBack) ...[
        FloatingActionButton(
          key: const ValueKey('wizard_back_fab'),
          heroTag: 'wizard_back_fab',
          onPressed: onBack,
          tooltip: 'Back',
          backgroundColor: onBack != null
              ? theme.colorScheme.surfaceContainerHigh
              : Color.alphaBlend(
                  theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  theme.colorScheme.surface,
                ),
          foregroundColor: onBack != null
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          elevation: onBack != null ? 6.0 : 0.0,
          child: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 12),
      ],
      if (isAutoPlaying)
        FloatingActionButton(
          key: const ValueKey('auto_play_fab'),
          heroTag: 'auto_play_fab',
          onPressed: () => notifier.stopAutoPlay(),
          tooltip: canvasState.isPausing
              ? 'Pausing after current AI step...'
              : 'Pause Auto-Play',
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          child: canvasState.isPausing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.pause),
        )
      else
        FloatingActionButton(
          key: const ValueKey('auto_play_fab'),
          heroTag: 'auto_play_fab',
          onPressed: hasRefImage ? () => notifier.startAutoPlay(ref) : null,
          tooltip: hasRefImage
              ? 'Start Auto-Play Wizard'
              : 'Upload reference image to enable Auto-Play',
          backgroundColor: hasRefImage
              ? theme.colorScheme.tertiary
              : theme.colorScheme.surfaceContainerHigh,
          foregroundColor: hasRefImage
              ? theme.colorScheme.onTertiary
              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          elevation: hasRefImage ? 6.0 : 0.0,
          child: const Icon(Icons.play_arrow),
        ),
      if (hasNext) ...[
        const SizedBox(width: 12),
        FloatingActionButton(
          key: const ValueKey('wizard_next_fab'),
          heroTag: 'wizard_next_fab',
          onPressed: onNext,
          tooltip: 'Next',
          backgroundColor: onNext != null
              ? theme.colorScheme.primary
              : Color.alphaBlend(
                  theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  theme.colorScheme.surface,
                ),
          foregroundColor: onNext != null
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          elevation: onNext != null ? 6.0 : 0.0,
          highlightElevation: onNext != null ? 12.0 : 0.0,
          child: const Icon(Icons.arrow_forward),
        ),
      ],
    ],
  );
}
