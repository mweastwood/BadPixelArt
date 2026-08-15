import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../widgets/model_options_dialog.dart';
import '../widgets/decomposition_options_dialog.dart';
import '../widgets/ai_history_dock.dart';
import '../widgets/custom_palette_confirmation_dialog.dart';
import '../widgets/wizard_floating_action_buttons.dart';
import '../logic/wizard_state.dart';
import 'creations_screen.dart';
import 'canvas_screen.dart';
import 'logs_screen.dart';

import '../logic/app_route_manager.dart';
import '../logic/utils/app_version.dart';

class PixelArtScreen extends ConsumerStatefulWidget {
  final Uri? mockUri;
  const PixelArtScreen({super.key, this.mockUri});

  @override
  ConsumerState<PixelArtScreen> createState() => _PixelArtScreenState();
}

class _PixelArtScreenState extends ConsumerState<PixelArtScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final AppRouteManager _routeManager;

  @override
  void initState() {
    super.initState();
    _routeManager = AppRouteManager(mockUri: widget.mockUri);
    _tabController = TabController(length: 3, initialIndex: 1, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _routeManager.handleUrlParameters(tabController: _tabController);
      }
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
    _routeManager.updateUrlPath(_tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _setupDecompositionDialogListener(BuildContext context, WidgetRef ref) {
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
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);
    final isDraggingCanvas = ref.watch(isDraggingCanvasProvider);
    final history = canvasState.aiHistory;

    _setupDecompositionDialogListener(context, ref);

    final double totalCost = history.fold(
      0.0,
      (sum, item) => sum + (item.estimatedCostUsd ?? 0.0),
    );

    return Stack(
      children: [
        Scaffold(
          drawer: _buildDrawer(context, canvasState, notifier, theme),
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
                    ? const WizardFloatingActionButtons()
                    : _buildLogsFloatingActionButtons(context, history, theme)),
        ),
        if (canvasState.showPaletteSuggestion &&
            canvasState.suggestedPalette != null)
          const CustomPaletteConfirmationDialog(),
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

  Widget _buildDrawer(
    BuildContext context,
    CanvasModel canvasState,
    CanvasNotifier notifier,
    ThemeData theme,
  ) {
    return Drawer(
      key: const ValueKey('app_hamburger_drawer'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Menu',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('drawer_creations_tile'),
            leading: const Icon(Icons.collections_outlined),
            title: const Text('Creations Gallery'),
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(0);
            },
          ),
          ListTile(
            key: const ValueKey('drawer_canvas_tile'),
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Canvas Studio'),
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(1);
            },
          ),
          ListTile(
            key: const ValueKey('drawer_logs_tile'),
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Conversation Logs'),
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(2);
            },
          ),
          const Divider(),
          ListTile(
            key: const ValueKey('drawer_model_options_tile'),
            leading: const Icon(Icons.settings),
            title: const Text('Model Options'),
            onTap: () {
              Navigator.pop(context);
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
          const Divider(),
          ListTile(
            key: const ValueKey('drawer_version_tile'),
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text(
              AppVersion.display,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildLogsFloatingActionButtons(
  BuildContext context,
  List<AgentHistoryEntry> history,
  ThemeData theme,
) {
  if (!kIsWeb) {
    return FloatingActionButton(
      key: const ValueKey('export_logs_fab'),
      heroTag: 'export_logs_fab',
      onPressed: () => exportAiHistory(context, history),
      tooltip: 'Export Logs',
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      child: const Icon(Icons.file_download_outlined),
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      FloatingActionButton.small(
        key: const ValueKey('copy_logs_fab'),
        heroTag: 'copy_logs_fab',
        onPressed: () => copyAiHistoryToClipboard(context, history),
        tooltip: 'Copy Logs to Clipboard',
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: const Icon(Icons.content_copy),
      ),
      const SizedBox(height: 12),
      FloatingActionButton(
        key: const ValueKey('export_logs_fab'),
        heroTag: 'export_logs_fab',
        onPressed: () => exportAiHistory(context, history),
        tooltip: 'Download Logs',
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.file_download_outlined),
      ),
    ],
  );
}
