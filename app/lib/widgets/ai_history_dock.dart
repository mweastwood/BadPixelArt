import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../logic/canvas_state.dart';

class AiHistoryDock extends ConsumerStatefulWidget {
  const AiHistoryDock({super.key});

  @override
  ConsumerState<AiHistoryDock> createState() => _AiHistoryDockState();
}

class _AiHistoryDockState extends ConsumerState<AiHistoryDock> {
  bool _isCollapsed = true;

  Future<void> _exportHistory(
    BuildContext context,
    List<AiHistoryEntry> history,
  ) async {
    if (history.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No history to export')));
      return;
    }

    try {
      final List<Map<String, dynamic>> jsonList = history.map((entry) {
        return {
          'timestamp': entry.timestamp.toIso8601String(),
          'prompt': entry.prompt,
          'response': entry.response,
          'isError': entry.isError,
          'canvasImageBase64': entry.canvasImage != null
              ? base64Encode(entry.canvasImage!)
              : null,
        };
      }).toList();

      final String jsonStr = const JsonEncoder.withIndent(
        '  ',
      ).convert(jsonList);

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
        // saveFile might not be supported on this platform/shell setup
        outputFile = null;
      }

      if (outputFile == null) {
        // Fallback: save to exports folder or current directory
        final exportsDir = Directory(
          '/home/mweastwood/projects/BadPixelArt/exports',
        );
        final targetDir = await exportsDir.exists()
            ? exportsDir.path
            : Directory.current.path;

        final defaultPath =
            '$targetDir/ai_drawing_history_${DateTime.now().millisecondsSinceEpoch}.json';
        final file = File(defaultPath);
        await file.writeAsString(jsonStr);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported to: ${osPathBasename(defaultPath)}'),
              action: SnackBarAction(
                label: 'Copy Path',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: defaultPath));
                },
              ),
            ),
          );
        }
        return;
      }

      final file = File(outputFile);
      await file.writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported successfully to: ${osPathBasename(outputFile)}',
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
    return path.split(Platform.isWindows ? '\\' : '/').last;
  }

  @override
  Widget build(BuildContext context) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);
    final history = canvasModel.aiHistory;

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
                    Icon(
                      Icons.bug_report_outlined,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI History & Debugger',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (history.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${history.length}',
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (!_isCollapsed && history.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.file_download_outlined),
                        tooltip: 'Export Logs',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _exportHistory(context, history),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        tooltip: 'Clear History',
                        visualDensity: VisualDensity.compact,
                        onPressed: notifier.clearAiHistory,
                      ),
                    ],
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
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No AI history logs yet.\nTrigger a suggestion to log prompts/responses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final entry =
                        history[history.length -
                            1 -
                            index]; // Show latest first
                    return _HistoryItem(entry: entry);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatefulWidget {
  final AiHistoryEntry entry;
  const _HistoryItem({required this.entry});

  @override
  State<_HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<_HistoryItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr =
        '${widget.entry.timestamp.hour.toString().padLeft(2, '0')}:${widget.entry.timestamp.minute.toString().padLeft(2, '0')}:${widget.entry.timestamp.second.toString().padLeft(2, '0')}';

    Map<String, dynamic>? parsedJson;
    try {
      final decoded = jsonDecode(widget.entry.response);
      if (decoded is Map<String, dynamic>) {
        parsedJson = decoded;
      }
    } catch (_) {}

    final understanding = parsedJson?['understanding'] as String?;
    final reasoning = parsedJson?['reasoning'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Log Summary Row
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: Row(
              children: [
                Icon(
                  widget.entry.isError
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: widget.entry.isError
                      ? theme.colorScheme.error
                      : Colors.green,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.entry.isError
                        ? 'AI Generation Error'
                        : 'Stroke suggested successfully',
                    style: TextStyle(
                      color: widget.entry.isError
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        // Expanded Prompt & Response Detail
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.entry.canvasImage != null) ...[
                  Text(
                    'CANVAS SNAPSHOT:',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          widget.entry.canvasImage!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                ],

                if (understanding != null) ...[
                  Text(
                    'AI UNDERSTANDING:',
                    style: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    understanding,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                ],
                if (reasoning != null) ...[
                  Text(
                    'AI REASONING:',
                    style: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reasoning,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                ],
                // Prompt Detail
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROMPT:',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy Prompt',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.entry.prompt),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Prompt copied to clipboard'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.entry.prompt,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),

                // Response Detail
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RESPONSE:',
                      style: TextStyle(
                        color: widget.entry.isError
                            ? theme.colorScheme.error
                            : Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    widget.entry.response,
                    style: TextStyle(
                      color: widget.entry.isError
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
