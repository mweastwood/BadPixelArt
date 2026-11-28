import 'dart:convert';
import 'dart:io';

import 'package:pixel_art_core/pixel_art_core.dart';

void main(List<String> args) {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    _printUsage();
    return;
  }

  final command = args.first;
  final rest = args.sublist(1);

  try {
    switch (command) {
      case 'render':
        _handleRender(rest);
      case 'inspect':
        _handleInspect(rest);
      case 'palettes':
        _handlePalettes();
      case 'tools':
        _handleTools();
      default:
        stderr.writeln('Unknown command: "$command"\n');
        _printUsage();
        exitCode = 64;
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    exitCode = 1;
  }
}

void _printUsage() {
  stdout.writeln('''
pixel_art — Pure-Dart BadPixelArt CLI engine

Usage:
  pixel_art render <scene.json> [options]
  pixel_art inspect <scene.json>
  pixel_art palettes
  pixel_art tools

Render options:
  --out <path.png>        Write clean pixel-art PNG (supports --scale, --bg)
  --svg <path.svg>        Write run-length-optimized crispEdges SVG
  --preview <path.png>    Write upscaled debug preview PNG with grid & coordinate rulers
  --scale <int>           Integer scale factor for --out PNG / --svg (default: 16)
  --cell-size <int>       Cell size in pixels for --preview PNG (default: 20)
  --bg <#RRGGBB>          Solid background hex color for --out / --svg (default: transparent)
  --no-grid               Hide gridlines in --preview PNG
  --no-rulers             Hide coordinate rulers in --preview PNG
  --no-palette            Hide palette legend bar in --preview PNG
  --ascii                 Print ASCII grid with coordinate rulers to stdout
  --json-grid <path.json> Dump resolved {gridSize, palette, grid} JSON
''');
}

void _handleRender(List<String> args) {
  String? inputPath;
  String? outPngPath;
  String? outSvgPath;
  String? previewPath;
  String? jsonGridPath;
  int scale = 16;
  int cellSize = 20;
  PixelColor? bgColor;
  bool showGrid = true;
  bool showRulers = true;
  bool showPalette = true;
  bool printAscii = false;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--out':
      case '-o':
        outPngPath = _requireValue(args, ++i, arg);
      case '--svg':
        outSvgPath = _requireValue(args, ++i, arg);
      case '--preview':
        previewPath = _requireValue(args, ++i, arg);
      case '--json-grid':
        jsonGridPath = _requireValue(args, ++i, arg);
      case '--scale':
        scale = int.parse(_requireValue(args, ++i, arg));
      case '--cell-size':
        cellSize = int.parse(_requireValue(args, ++i, arg));
      case '--bg':
        bgColor = PixelColor.parseHex(_requireValue(args, ++i, arg));
      case '--no-grid':
        showGrid = false;
      case '--no-rulers':
        showRulers = false;
      case '--no-palette':
        showPalette = false;
      case '--ascii':
        printAscii = true;
      default:
        if (arg.startsWith('-')) {
          throw ArgumentError('Unknown option: $arg');
        }
        inputPath ??= arg;
    }
  }

  if (inputPath == null) {
    throw ArgumentError('Missing required <scene.json> input path.');
  }

  final file = File(inputPath);
  if (!file.existsSync()) {
    throw FileSystemException('Scene file not found', inputPath);
  }

  final scene = PixelArtScene.fromJsonString(file.readAsStringSync());
  final result = scene.render();

  final transparent = bgColor == null;
  final effectiveBg = bgColor ?? const PixelColor(0xFF1E1E1E);

  if (outPngPath != null) {
    final bytes = PngEncoder.encodeGrid(
      result.grid,
      result.palette,
      scale: scale,
      transparentBackground: transparent,
      backgroundColor: effectiveBg,
    );
    _writeBytes(outPngPath, bytes);
    stdout.writeln(
      'Wrote PNG: $outPngPath (${result.gridSize * scale}x${result.gridSize * scale}, ${bytes.length} bytes)',
    );
  }

  if (outSvgPath != null) {
    final svg = generateSvgString(
      result.grid,
      result.palette,
      scale: scale,
      transparentBackground: transparent,
      backgroundColor: effectiveBg,
    );
    _writeString(outSvgPath, svg);
    stdout.writeln('Wrote SVG: $outSvgPath (${svg.length} chars)');
  }

  if (previewPath != null) {
    final previewBytes = PreviewRenderer.renderPreviewPng(
      result.grid,
      result.palette,
      cellSize: cellSize,
      showGridLines: showGrid,
      showRulers: showRulers,
      showPaletteBar: showPalette,
    );
    _writeBytes(previewPath, previewBytes);
    stdout.writeln(
      'Wrote preview PNG: $previewPath (${previewBytes.length} bytes)',
    );
  }

  if (jsonGridPath != null) {
    final payload = const JsonEncoder.withIndent('  ').convert({
      'title': result.title,
      'gridSize': result.gridSize,
      'palette': result.palette.map((c) => c.toHex(uppercase: true)).toList(),
      'grid': result.grid,
    });
    _writeString(jsonGridPath, payload);
    stdout.writeln('Wrote grid JSON: $jsonGridPath');
  }

  if (printAscii ||
      (outPngPath == null &&
          outSvgPath == null &&
          previewPath == null &&
          jsonGridPath == null)) {
    stdout.writeln(PreviewRenderer.formatAsciiGrid(result.grid));
  }

  if (result.warnings.isNotEmpty) {
    stderr.writeln('Warnings (${result.warnings.length}):');
    for (final w in result.warnings) {
      stderr.writeln('  - $w');
    }
  }
}

void _handleInspect(List<String> args) {
  if (args.isEmpty) {
    throw ArgumentError('Missing required <scene.json> input path.');
  }
  final file = File(args.first);
  final scene = PixelArtScene.fromJsonString(file.readAsStringSync());
  final result = scene.render();

  final totalCells = result.gridSize * result.gridSize;
  final filled = result.filledPixelCount;
  final pct = totalCells > 0
      ? (filled * 100.0 / totalCells).toStringAsFixed(1)
      : '0.0';

  stdout.writeln('Title: ${result.title}');
  stdout.writeln(
    'Grid: ${result.gridSize}x${result.gridSize} ($filled/$totalCells pixels filled, $pct%)',
  );
  stdout.writeln('Palette (${result.palette.length} colors):');

  final usage = result.colorUsage;
  final indexToName = <int, String>{};
  for (final e in result.colorNames.entries) {
    indexToName[e.value] = e.key;
  }

  for (int i = 0; i < result.palette.length; i++) {
    final idx = i + 1;
    final sym = PreviewRenderer.indexToSymbol(idx);
    final hex = result.palette[i].toHex(uppercase: true);
    final name = indexToName[idx] != null ? ' (${indexToName[idx]})' : '';
    final count = usage[idx] ?? 0;
    stdout.writeln('  [$sym] #$idx $hex$name — $count px');
  }

  stdout.writeln();
  stdout.write(PreviewRenderer.formatAsciiGrid(result.grid));

  if (result.warnings.isNotEmpty) {
    stdout.writeln('\nWarnings (${result.warnings.length}):');
    for (final w in result.warnings) {
      stdout.writeln('  - $w');
    }
  }
}

void _handlePalettes() {
  for (final p in PaletteRegistry.presets) {
    final hexes = p.colors.map((c) => c.toHex(uppercase: true)).join(', ');
    stdout.writeln('${p.id} (${p.displayName}, ${p.colors.length} colors):');
    stdout.writeln('  $hexes');
  }
}

void _handleTools() {
  for (final entry in DrawingCommandFactory.toolInstructions.entries) {
    if (entry.key == 'undo') continue;
    stdout.writeln('- ${entry.key}: ${entry.value}');
  }
}

String _requireValue(List<String> args, int idx, String flag) {
  if (idx >= args.length) {
    throw ArgumentError('Option $flag requires a value.');
  }
  return args[idx];
}

void _writeBytes(String path, List<int> bytes) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes);
}

void _writeString(String path, String content) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content);
}
