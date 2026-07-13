import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_agent/local_agent.dart';
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

      // If saveFile is not supported/returns null, try getDirectoryPath to let the user choose where to save
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
        // Fallback: save to exports folder, current directory (if not root), or system temp directory
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
                    return _HistoryItem(
                      entry: entry,
                      palette: canvasModel.palette,
                    );
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
  final AgentHistoryEntry entry;
  final List<Color> palette;
  const _HistoryItem({required this.entry, required this.palette});

  @override
  State<_HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<_HistoryItem> {
  bool _expanded = false;
  int _selectedPainterIndex = 0;

  void _showRawExchangeDialog(
    BuildContext context, {
    required String title,
    required String prompt,
    required String response,
    Uint8List? imageBytes,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 450),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageBytes != null) ...[
                    Text(
                      'VISUAL INPUT:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            imageBytes,
                            height: 128,
                            width: 128,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RAW PROMPT:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: prompt));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied prompt to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      prompt,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RAW RESPONSE:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: response));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied response to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      response,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  bool _useWhiteText(Color color) {
    return color.computeLuminance() < 0.5;
  }

  IconData _getToolIcon(String tool) {
    switch (tool) {
      case 'error':
        return Icons.error_outline;
      case 'undo':
        return Icons.undo;
      case 'pixel':
      case 'pixels':
        return Icons.gesture;
      case 'line':
        return Icons.show_chart;
      case 'circle':
      case 'ellipse':
        return Icons.radio_button_unchecked;
      case 'circle_filled':
        return Icons.lens;
      case 'circle_hatched':
        return Icons.blur_circular;
      case 'rectangle':
        return Icons.check_box_outline_blank;
      case 'rectangle_filled':
        return Icons.square;
      case 'rectangle_hatched':
        return Icons.grid_view;
      case 'fill':
        return Icons.format_color_fill;
      case 'hatch':
        return Icons.grain;
      default:
        return Icons.brush;
    }
  }

  String _formatParamsText(String tool, List<dynamic> params) {
    if (params.isEmpty) return '';
    try {
      switch (tool) {
        case 'pixel':
          return 'at (${params[0]}, ${params[1]})';
        case 'pixels':
          final coords = [];
          for (int i = 0; i < params.length - 1; i += 2) {
            coords.add('(${params[i]}, ${params[i + 1]})');
          }
          return 'at ${coords.join(', ')}';
        case 'line':
          return 'from (${params[0]}, ${params[1]}) to (${params[2]}, ${params[3]})';
        case 'circle':
        case 'circle_filled':
        case 'circle_hatched':
        case 'noise_circle':
          return 'center (${params[0]}, ${params[1]}) radius ${params[2]}';
        case 'rectangle':
        case 'rectangle_filled':
        case 'rectangle_hatched':
        case 'noise_rectangle':
          return 'from (${params[0]}, ${params[1]}) to (${params[2]}, ${params[3]})';
        case 'fill':
        case 'hatch':
          return 'start at (${params[0]}, ${params[1]})';
        case 'ellipse':
          return 'center (${params[0]}, ${params[1]}) radii (${params[2]}, ${params[3]})';
        case 'voronoi':
          return 'with ${params[0]} points';
      }
    } catch (_) {}
    return 'params: ${params.join(', ')}';
  }

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

    final int? criticChoice = parsedJson?['criticChoice'] as int?;
    final String? criticReasoning = parsedJson?['criticReasoning'] as String?;
    final isTournament = criticChoice != null;

    final painterJson = parsedJson?['painter'] as Map<String, dynamic>?;
    final criticJson = parsedJson?['critic'] as Map<String, dynamic>?;

    final understanding =
        painterJson?['understanding'] as String? ??
        parsedJson?['understanding'] as String?;
    final reasoning =
        painterJson?['reasoning'] as String? ??
        parsedJson?['reasoning'] as String?;
    final criticAction = criticJson?['action'] as String?;
    final criticReasoningOld = criticJson?['reasoning'] as String?;

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
                      : (isTournament
                            ? Icons.stars
                            : (criticAction == 'undo'
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline)),
                  color: widget.entry.isError
                      ? theme.colorScheme.error
                      : (isTournament
                            ? theme.colorScheme.primary
                            : (criticAction == 'undo'
                                  ? theme.colorScheme.error
                                  : Colors.green)),
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
                        : (isTournament
                              ? 'Critic picked Painter $criticChoice'
                              : (criticAction == 'undo'
                                    ? 'Stroke rejected by critic'
                                    : 'Stroke suggested successfully')),
                    style: TextStyle(
                      color: widget.entry.isError
                          ? theme.colorScheme.error
                          : (criticAction == 'undo'
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isTournament) ...[
                  IconButton(
                    icon: const Icon(Icons.code, size: 16),
                    tooltip: 'View Raw AI Exchange',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _showRawExchangeDialog(
                        context,
                        title: 'Raw LLM Exchange: Stroke Suggestion',
                        prompt: widget.entry.prompt,
                        response: widget.entry.response,
                        imageBytes: widget.entry.imageBytes,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
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
                if (isTournament) ...[
                  // Verdict Card
                  Card(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.gavel_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'CRITIC VERDICT: SELECTED PAINTER $criticChoice',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.code, size: 16),
                                tooltip: 'View Raw Critic Exchange',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _showRawExchangeDialog(
                                    context,
                                    title: 'Raw LLM Exchange: Critic Verdict',
                                    prompt:
                                        parsedJson?['criticRawPrompt']
                                            as String? ??
                                        'N/A',
                                    response:
                                        parsedJson?['criticRawResponse']
                                            as String? ??
                                        'N/A',
                                    imageBytes: widget.entry.imageBytes,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            criticReasoning ?? 'No reasoning provided.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2x2 Snapshot Grid
                  if (widget.entry.imageBytes != null) ...[
                    Text(
                      'TOURNAMENT COMPARISON GRID (2x2):',
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
                        width: 160,
                        height: 160,
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
                            widget.entry.imageBytes!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Top-Left: Ref | Top-Right: P1 | Bottom-Left: P2 | Bottom-Right: P3',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],

                  // Describer Canvas Descriptions
                  if (parsedJson?['describers'] != null) ...[
                    Text(
                      'DESCRIBER CANVAS DESCRIPTIONS:',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...(parsedJson!['describers'] as Map<String, dynamic>)
                        .entries
                        .map((e) {
                          final key = e.key;
                          final descData = e.value as Map<String, dynamic>?;
                          if (descData == null) return const SizedBox.shrink();
                          final description =
                              descData['description'] as String? ?? 'N/A';
                          final rawPrompt =
                              descData['rawPrompt'] as String? ?? 'N/A';
                          final rawResponse =
                              descData['rawResponse'] as String? ?? 'N/A';
                          final imgBytesBase64 =
                              descData['imageBytes'] as String?;
                          final Uint8List? imgBytes = imgBytesBase64 != null
                              ? base64Decode(imgBytesBase64)
                              : null;

                          String label = 'Target Reference';
                          if (key == 'starting') {
                            label = 'Starting Canvas';
                          }
                          if (key == 'candidate1') {
                            label = 'Candidate 1 (Painter Run 1)';
                          }
                          if (key == 'candidate2') {
                            label = 'Candidate 2 (Painter Run 2)';
                          }
                          if (key == 'candidate3') {
                            label = 'Candidate 3 (Painter Run 3)';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            color: theme.colorScheme.surfaceContainerHigh,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 6.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (imgBytes != null) ...[
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: theme
                                                  .colorScheme
                                                  .outlineVariant,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            child: Image.memory(
                                              imgBytes,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.none,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          label.toUpperCase(),
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.code, size: 14),
                                        tooltip: 'View Raw Describer Exchange',
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          _showRawExchangeDialog(
                                            context,
                                            title:
                                                'Raw LLM Exchange: Describer ($label)',
                                            prompt: rawPrompt,
                                            response: rawResponse,
                                            imageBytes: imgBytes,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 11.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],

                  // Tab Buttons for Painter 1, 2, 3
                  Text(
                    'PAINTER PROGRESSION TIMELINE:',
                    style: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(3, (i) {
                      final isChosen = (criticChoice == i + 1);
                      final isSelected = (_selectedPainterIndex == i);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedPainterIndex = i),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isChosen
                                      ? Colors.green
                                      : (isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outlineVariant),
                                  width: isChosen ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isChosen
                                            ? Icons.check_circle
                                            : Icons.person_outline,
                                        size: 13,
                                        color: isChosen
                                            ? Colors.green
                                            : (isSelected
                                                  ? theme.colorScheme.primary
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Painter ${i + 1}',
                                        style: TextStyle(
                                          color: isSelected
                                              ? theme
                                                    .colorScheme
                                                    .onPrimaryContainer
                                              : theme.colorScheme.onSurface,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Strokes List for selected Painter
                  () {
                    final List<dynamic>? strokes =
                        parsedJson?['painter${_selectedPainterIndex + 1}Strokes']
                            as List<dynamic>?;
                    if (strokes == null || strokes.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Text(
                            'No strokes recorded for this Painter.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: strokes.length,
                      itemBuilder: (context, strokeIdx) {
                        final stroke = strokes[strokeIdx];
                        final tool = stroke['tool'] as String? ?? 'unknown';
                        final params = stroke['params'] as List<dynamic>? ?? [];
                        final colorIdx = stroke['color'] as int? ?? 0;
                        final isErrorTool = tool == 'error';

                        Color? strokeColor;
                        if (isErrorTool) {
                          strokeColor = theme.colorScheme.error;
                        } else if (colorIdx >= 0 &&
                            colorIdx < widget.palette.length) {
                          strokeColor = widget.palette[colorIdx];
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: strokeColor ?? Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isErrorTool
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.outline,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isErrorTool ? '!' : '${strokeIdx + 1}',
                                style: TextStyle(
                                  color: strokeColor != null
                                      ? (_useWhiteText(strokeColor)
                                            ? Colors.white
                                            : Colors.black)
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Icon(
                                  _getToolIcon(tool),
                                  size: 14,
                                  color: isErrorTool
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tool,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: isErrorTool
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.onSurface,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              isErrorTool
                                  ? (stroke['error'] as String? ??
                                        'An error occurred')
                                  : _formatParamsText(tool, params),
                              style: TextStyle(
                                color: isErrorTool
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.code, size: 14),
                              tooltip: 'View Raw Painter Exchange',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final String? rawImageBase64 =
                                    stroke['rawImageBase64'] as String?;
                                final Uint8List? imageBytes =
                                    rawImageBase64 != null
                                    ? base64Decode(rawImageBase64)
                                    : null;
                                _showRawExchangeDialog(
                                  context,
                                  title:
                                      'Raw LLM Exchange: Painter ${_selectedPainterIndex + 1} - Turn ${strokeIdx + 1}',
                                  prompt:
                                      stroke['rawPrompt'] as String? ?? 'N/A',
                                  response:
                                      stroke['rawResponse'] as String? ?? 'N/A',
                                  imageBytes: imageBytes,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  }(),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                ] else ...[
                  // Fallback for non-tournament / legacy entries
                  if (widget.entry.imageBytes != null) ...[
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
                            widget.entry.imageBytes!,
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
                  if (criticAction != null) ...[
                    Text(
                      'CRITIC EVALUATION (${criticAction.toUpperCase()}):',
                      style: TextStyle(
                        color: criticAction == 'undo'
                            ? theme.colorScheme.error
                            : Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      criticReasoningOld ?? 'No reasoning provided.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
