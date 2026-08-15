import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'web_download.dart';

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

Future<void> copyAiHistoryToClipboard(
  BuildContext context,
  List<AgentHistoryEntry> history,
) async {
  if (history.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No history to copy')));
    return;
  }

  final String jsonStr = AgentHistoryEntry.serializeList(history);
  await Clipboard.setData(ClipboardData(text: jsonStr));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI History copied to clipboard!')),
    );
  }
}

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
      final fileName =
          'ai_drawing_history_${DateTime.now().millisecondsSinceEpoch}.json';
      downloadFileWeb(jsonStr, fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI History downloaded as JSON!')),
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
