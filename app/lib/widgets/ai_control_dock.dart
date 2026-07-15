import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'package:local_agent/local_agent.dart';

class AiControlDock extends ConsumerStatefulWidget {
  const AiControlDock({super.key});

  @override
  ConsumerState<AiControlDock> createState() => _AiControlDockState();
}

class _AiControlDockState extends ConsumerState<AiControlDock> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row (Tappable to expand/collapse)
            InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4.0,
                  horizontal: 4.0,
                ),
                child: Row(
                  children: [
                    Text(
                      'AI Assistant Controls',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(canvasModel.aiStatus, notifier),
                    const SizedBox(width: 8),
                    Icon(
                      _isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (!_isCollapsed) ...[
              const SizedBox(height: 12),

              // AI Controls (Suggest, Auto-Run, Speed)
              Row(
                children: [
                  // Suggest Next Stroke Button
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: canvasModel.isGenerating
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.psychology),
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
                  ),
                  const SizedBox(width: 12),

                  // Auto Run Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: IconButton(
                      tooltip: canvasModel.autoRun
                          ? 'Pause Auto-Run'
                          : 'Start Auto-Run',
                      icon: Icon(
                        canvasModel.autoRun ? Icons.pause : Icons.play_arrow,
                        color: canvasModel.autoRun
                            ? Colors.amber
                            : Colors.green,
                        size: 28,
                      ),
                      onPressed: canvasModel.aiStatus == AiCoreStatus.available
                          ? notifier.toggleAutoRun
                          : null,
                    ),
                  ),
                ],
              ),

              if (canvasModel.autoRun) ...[
                const SizedBox(height: 16),
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
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
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
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(AiCoreStatus status, CanvasNotifier notifier) {
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
