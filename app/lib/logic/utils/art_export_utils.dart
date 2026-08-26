import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'bmp_utils.dart';
import 'web_download.dart';

/// Supported export formats for pixel art creations.
enum ExportFormat { png, svg }

/// Sanitizes a string to be safely used as a filename.
String sanitizeFileName(String input, {String fallback = 'pixel_art'}) {
  final clean = input
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  if (clean.isEmpty || clean == '_') {
    return '${fallback}_${DateTime.now().millisecondsSinceEpoch}';
  }
  return clean;
}

/// Formats a Color into a 6-character hex string (e.g. `#FF00FF`).
String colorToHex(Color color) {
  final r = color.rInt.toRadixString(16).padLeft(2, '0');
  final g = color.gInt.toRadixString(16).padLeft(2, '0');
  final b = color.bInt.toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

/// Generates PNG encoded byte data from a pixel art [grid] and [palette].
///
/// Supports integer [scale] factors (1x, 2x, 4x, 8x, etc.) using crisp point/nearest-neighbor scaling,
/// and optional [transparentBackground] for empty/background cells (index 0).
Future<Uint8List> generatePngBytes(
  List<List<int>> grid,
  List<Color> palette, {
  int scale = 1,
  bool transparentBackground = true,
  Color backgroundColor = const Color(0xFF1E1E1E),
}) async {
  final int height = grid.length;
  final int width = grid.isNotEmpty ? grid[0].length : 0;
  if (width == 0 || height == 0 || scale <= 0) {
    return Uint8List(0);
  }

  final int outWidth = width * scale;
  final int outHeight = height * scale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (!transparentBackground) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
      Paint()
        ..color = backgroundColor
        ..isAntiAlias = false,
    );
  }

  final cellPaint = Paint()..isAntiAlias = false;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final colorIndex = grid[y][x];
      if (colorIndex > 0 && colorIndex <= palette.length) {
        cellPaint.color = palette[colorIndex - 1];
        canvas.drawRect(
          Rect.fromLTWH(
            (x * scale).toDouble(),
            (y * scale).toDouble(),
            scale.toDouble(),
            scale.toDouble(),
          ),
          cellPaint,
        );
      }
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(outWidth, outHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  if (byteData == null) {
    return Uint8List(0);
  }
  return byteData.buffer.asUint8List();
}

/// Generates an SVG vector string representation of the pixel art [grid] and [palette].
///
/// Optimizes horizontal spans of identical colors into single rectangle elements with crisp edges.
String generateSvgString(
  List<List<int>> grid,
  List<Color> palette, {
  int scale = 1,
  bool transparentBackground = true,
  Color backgroundColor = const Color(0xFF1E1E1E),
}) {
  final int height = grid.length;
  final int width = grid.isNotEmpty ? grid[0].length : 0;
  if (width == 0 || height == 0 || scale <= 0) {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1" width="1" height="1"></svg>';
  }

  final int outWidth = width * scale;
  final int outHeight = height * scale;

  final buffer = StringBuffer();
  buffer.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" width="$outWidth" height="$outHeight" shape-rendering="crispEdges">',
  );

  if (!transparentBackground) {
    final bgHex = colorToHex(backgroundColor);
    buffer.writeln('  <rect width="100%" height="100%" fill="$bgHex" />');
  }

  // Combine contiguous horizontal pixels of the same color into a single <rect>
  for (int y = 0; y < height; y++) {
    int x = 0;
    while (x < width) {
      final colorIndex = grid[y][x];
      if (colorIndex > 0 && colorIndex <= palette.length) {
        int runLength = 1;
        while (x + runLength < width && grid[y][x + runLength] == colorIndex) {
          runLength++;
        }
        final color = palette[colorIndex - 1];
        final hex = colorToHex(color);
        final double opacity = color.aInt / 255.0;
        if (opacity < 1.0) {
          buffer.writeln(
            '  <rect x="$x" y="$y" width="$runLength" height="1" fill="$hex" fill-opacity="${opacity.toStringAsFixed(2)}" />',
          );
        } else {
          buffer.writeln(
            '  <rect x="$x" y="$y" width="$runLength" height="1" fill="$hex" />',
          );
        }
        x += runLength;
      } else {
        x++;
      }
    }
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

/// Handles saving or downloading exported art bytes across Web, Desktop, and Mobile.
Future<bool> saveExportedArtFile({
  required BuildContext context,
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required String extension,
}) async {
  if (bytes.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot export empty canvas')),
      );
    }
    return false;
  }

  try {
    if (kIsWeb) {
      downloadBytesWeb(bytes, fileName, mimeType);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "$fileName"!'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return true;
    }

    String? outputFile;
    try {
      outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Pixel Art',
        fileName: fileName,
        allowedExtensions: [extension],
        type: FileType.custom,
      );
    } catch (_) {
      outputFile = null;
    }

    if (outputFile == null) {
      try {
        final String? selectedDir = await FilePicker.getDirectoryPath(
          dialogTitle: 'Select Directory to Save Pixel Art',
        );
        if (selectedDir != null) {
          outputFile = p.join(selectedDir, fileName);
        }
      } catch (_) {
        outputFile = null;
      }
    }

    if (outputFile == null) {
      String targetDir;
      try {
        final appDocsDir = await getApplicationDocumentsDirectory();
        targetDir = appDocsDir.path;
      } catch (_) {
        targetDir = Directory.systemTemp.path;
      }
      outputFile = p.join(targetDir, fileName);
    }

    final file = File(outputFile);
    await file.writeAsBytes(bytes);

    if (context.mounted) {
      final finalPath = outputFile;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported successfully to: ${p.basename(outputFile)}'),
          action: SnackBarAction(
            label: 'Copy Path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: finalPath));
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting pixel art: $e')));
    }
    return false;
  }
}

/// Exports artwork as a PNG image.
Future<bool> exportArtworkAsPng(
  BuildContext context, {
  required List<List<int>> grid,
  required List<Color> palette,
  required String title,
  int scale = 8,
  bool transparentBackground = true,
  Color backgroundColor = const Color(0xFF1E1E1E),
}) async {
  final bytes = await generatePngBytes(
    grid,
    palette,
    scale: scale,
    transparentBackground: transparentBackground,
    backgroundColor: backgroundColor,
  );
  final sanitized = sanitizeFileName(title);
  final fileName = '$sanitized.png';
  if (!context.mounted) return false;
  return saveExportedArtFile(
    context: context,
    bytes: bytes,
    fileName: fileName,
    mimeType: 'image/png',
    extension: 'png',
  );
}

/// Exports artwork as an SVG vector image.
Future<bool> exportArtworkAsSvg(
  BuildContext context, {
  required List<List<int>> grid,
  required List<Color> palette,
  required String title,
  int scale = 8,
  bool transparentBackground = true,
  Color backgroundColor = const Color(0xFF1E1E1E),
}) async {
  final svgString = generateSvgString(
    grid,
    palette,
    scale: scale,
    transparentBackground: transparentBackground,
    backgroundColor: backgroundColor,
  );
  final bytes = Uint8List.fromList(utf8.encode(svgString));
  final sanitized = sanitizeFileName(title);
  final fileName = '$sanitized.svg';
  if (!context.mounted) return false;
  return saveExportedArtFile(
    context: context,
    bytes: bytes,
    fileName: fileName,
    mimeType: 'image/svg+xml',
    extension: 'svg',
  );
}
