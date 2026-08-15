import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../logic/canvas_state.dart';
import '../logic/utils/ai_history_export_utils.dart';
import '../logic/utils/settings_provider.dart';

class AiHistoryDock extends ConsumerWidget {
  const AiHistoryDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasModel = ref.watch(canvasStateProvider);
    final theme = Theme.of(context);
    final history = canvasModel.aiHistory;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No AI history logs yet.\nTrigger a prompt to view conversation history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 12.0,
        bottom: 80.0,
      ),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[history.length - 1 - index];
        return _ChatMessageTurn(entry: entry);
      },
    );
  }
}

class _ChatMessageTurn extends ConsumerWidget {
  final AgentHistoryEntry entry;

  const _ChatMessageTurn({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final timeStr = formatLogTimestamp(entry.timestamp);

    final modelDisplayName =
        (entry.modelName != null && entry.modelName!.trim().isNotEmpty)
        ? entry.modelName!
        : settings.activeModelName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User Message Bubble (Right Aligned)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.only(top: 8, bottom: 4, left: 32),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'User',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                if (entry.imageBytes != null &&
                    entry.imageBytes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Image.memory(
                        entry.imageBytes!,
                        height: 120,
                        width: 120,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SelectableText(
                  entry.prompt,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                if (entry.inputTokens != null && entry.inputTokens! > 0) ...[
                  const SizedBox(height: 8),
                  _UserTokenCountBadge(inputTokens: entry.inputTokens!),
                ],
              ],
            ),
          ),
        ),

        // AI Response Message Bubble (Left Aligned)
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.only(top: 4, bottom: 12, right: 32),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: entry.isError
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: entry.isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: entry.isError
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      modelDisplayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: entry.isError
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (entry.response == 'Generating response...') ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Generating response...',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SelectableText(
                    entry.response,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: entry.isError
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
                if (entry.inputTokens != null ||
                    entry.outputTokens != null ||
                    (entry.estimatedCostUsd != null &&
                        entry.estimatedCostUsd! > 0)) ...[
                  const SizedBox(height: 8),
                  _ResponseTokenCountBadge(entry: entry),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserTokenCountBadge extends StatelessWidget {
  final int inputTokens;

  const _UserTokenCountBadge({required this.inputTokens});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        '$inputTokens tokens',
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ResponseTokenCountBadge extends StatelessWidget {
  final AgentHistoryEntry entry;

  const _ResponseTokenCountBadge({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inTokens = entry.inputTokens ?? 0;
    final outTokens = entry.outputTokens;
    final totalTokens =
        entry.totalTokens ??
        (entry.outputTokens != null
            ? inTokens + outTokens!
            : (inTokens > 0 ? inTokens : null));
    final cost = entry.estimatedCostUsd;

    final parts = <String>[];
    if (outTokens != null) {
      if (totalTokens != null) {
        parts.add('$outTokens tokens ($totalTokens total)');
      } else {
        parts.add('$outTokens tokens');
      }
    } else if (totalTokens != null && totalTokens > 0) {
      parts.add('$totalTokens tokens');
    }

    if (cost != null && cost > 0) {
      parts.add('\$${cost.toStringAsFixed(4)}');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        parts.join(' • '),
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
