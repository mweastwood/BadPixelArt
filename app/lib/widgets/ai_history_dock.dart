import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../logic/canvas_state.dart';

Future<void> exportAiHistory(
  BuildContext context,
  List<AgentHistoryEntry> history,
) async {
  if (history.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No history to export')));
    return;
  }

  try {
    final String jsonStr = AgentHistoryEntry.serializeList(history);

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI History copied to clipboard!')),
        );
      }
      return;
    }

    String? outputFile;
    try {
      outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save AI History Log',
        fileName:
            'ai_drawing_history_${DateTime.now().millisecondsSinceEpoch}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );
    } catch (e) {
      outputFile = null;
    }

    if (outputFile == null) {
      try {
        final String? selectedDir = await FilePicker.getDirectoryPath(
          dialogTitle: 'Select Directory to Save AI History Log',
        );
        if (selectedDir != null) {
          outputFile =
              '$selectedDir/ai_drawing_history_${DateTime.now().millisecondsSinceEpoch}.json';
        }
      } catch (_) {
        outputFile = null;
      }
    }

    if (outputFile == null) {
      final exportsDir = Directory(
        '/home/mweastwood/projects/BadPixelArt/exports',
      );
      String targetDir;
      if (await exportsDir.exists()) {
        targetDir = exportsDir.path;
      } else {
        final currentPath = Directory.current.path;
        if (currentPath != '/' && currentPath.isNotEmpty) {
          targetDir = currentPath;
        } else {
          targetDir = Directory.systemTemp.path;
        }
      }

      outputFile =
          '$targetDir/ai_drawing_history_${DateTime.now().millisecondsSinceEpoch}.json';
    }

    final file = File(outputFile);
    await file.writeAsString(jsonStr);

    if (context.mounted) {
      final finalPath = outputFile;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported successfully to: ${osPathBasename(outputFile)}',
          ),
          action: SnackBarAction(
            label: 'Copy Path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: finalPath));
            },
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting history: $e')));
    }
  }
}

String osPathBasename(String path) {
  return path.split(RegExp(r'[/\\]')).last;
}

String formatLogTimestamp(DateTime dt) {
  final year = dt.year;
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final second = dt.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}

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

class _ChatMessageTurn extends StatelessWidget {
  final AgentHistoryEntry entry;

  const _ChatMessageTurn({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = formatLogTimestamp(entry.timestamp);

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
                      'AI Assistant',
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
                if (entry.inputTokens != null ||
                    entry.outputTokens != null ||
                    (entry.estimatedCostUsd != null &&
                        entry.estimatedCostUsd! > 0)) ...[
                  const SizedBox(height: 8),
                  _TokenCountBadge(entry: entry),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TokenCountBadge extends StatelessWidget {
  final AgentHistoryEntry entry;

  const _TokenCountBadge({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inTokens = entry.inputTokens;
    final outTokens = entry.outputTokens;
    final cost = entry.estimatedCostUsd;

    final parts = <String>[];
    if (inTokens != null && outTokens != null) {
      parts.add(
        '${inTokens + outTokens} tokens (${inTokens}in / ${outTokens}out)',
      );
    } else if (inTokens != null) {
      parts.add('$inTokens in-tokens');
    } else if (outTokens != null) {
      parts.add('$outTokens out-tokens');
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
