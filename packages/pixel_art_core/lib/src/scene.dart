import 'dart:convert';

import 'bounded_canvas.dart';
import 'commands/drawing_command_factory.dart';
import 'commands/mirror_command.dart';
import 'commands/outline_command.dart';
import 'component.dart';
import 'palettes.dart';
import 'sprite_template.dart';
import 'types.dart';

/// Result of rendering a declarative [PixelArtScene] into a palette-indexed grid.
class SceneRenderResult {
  final String title;
  final int gridSize;
  final List<PixelColor> palette;
  final Map<String, int> colorNames;
  final List<List<int>> grid;
  final List<String> warnings;

  const SceneRenderResult({
    required this.title,
    required this.gridSize,
    required this.palette,
    required this.colorNames,
    required this.grid,
    required this.warnings,
  });

  /// Counts non-transparent pixels in [grid].
  int get filledPixelCount {
    int count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell > 0) count++;
      }
    }
    return count;
  }

  /// Counts pixels per palette index (1..palette.length).
  Map<int, int> get colorUsage {
    final counts = <int, int>{};
    for (final row in grid) {
      for (final cell in row) {
        if (cell > 0) {
          counts[cell] = (counts[cell] ?? 0) + 1;
        }
      }
    }
    return counts;
  }
}

/// Declarative scene runner for BadPixelArt.
///
/// Compiles a JSON scene specification into a final composited pixel grid,
/// supporting:
/// - Named palettes (`"sweetie16"`, `"pico8"`, etc.), hex lists, or named color maps
/// - Bottom-to-top layered compositing
/// - Three flexible layer styles (combinable on any layer):
///   1. **Component mask + Bayer gradient + outline** (`maskOps` / `shapes`, `add`, `remove`, `fill`, `fill2`, `gradientAngle`, `dither`, `outline`, `outlineMode`)
///   2. **Multi-color drawing commands** (`ops`: `[{tool, params, color}, ...]`)
///   3. **ASCII pixel rows** (`rows` + optional `legend`, `offsetX`, `offsetY`)
/// - Optional per-layer or scene-wide `mirrorH` / `mirrorV`
/// - Global `postOps` for final silhouettes (`auto_outline`), pixel touch-ups, and swaps
class PixelArtScene {
  final Map<String, dynamic> spec;

  PixelArtScene(this.spec);

  factory PixelArtScene.fromJsonString(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Scene JSON root must be an object.');
    }
    return PixelArtScene(decoded);
  }

  SceneRenderResult render() {
    final warnings = <String>[];
    final title = (spec['title'] as String?)?.trim().isNotEmpty == true
        ? (spec['title'] as String).trim()
        : 'pixel_art';

    final int gridSize = _parseInt(spec['gridSize'] ?? spec['size']) ?? 16;
    if (gridSize <= 0 || gridSize > 256) {
      throw RangeError.range(gridSize, 1, 256, 'gridSize');
    }

    // 1. Parse palette
    final palette = <PixelColor>[];
    final colorNames = <String, int>{};
    _parsePalette(spec['palette'], palette, colorNames, warnings);
    if (palette.isEmpty) {
      palette.addAll(PaletteRegistry.sweetie16Palette);
      warnings.add('No palette specified; defaulted to sweetie16.');
    }

    int resolveColor(dynamic raw, {int fallback = 1}) {
      if (raw == null) return fallback;
      if (raw is int) {
        if (raw == 0) return 0;
        if (raw >= 1 && raw <= palette.length) return raw;
        warnings.add('Color index $raw out of range 0..${palette.length}.');
        return raw.clamp(0, palette.length);
      }
      if (raw is num) {
        return resolveColor(raw.round(), fallback: fallback);
      }
      final s = raw.toString().trim();
      if (s.isEmpty ||
          s == '0' ||
          s.toLowerCase() == 'transparent' ||
          s.toLowerCase() == 'erase') {
        return 0;
      }
      final asInt = int.tryParse(s);
      if (asInt != null) {
        return resolveColor(asInt, fallback: fallback);
      }
      final named = colorNames[s.toLowerCase()];
      if (named != null) return named;

      final parsedHex = PixelColor.tryParseHex(s);
      if (parsedHex != null) {
        final existingIdx = palette.indexWhere(
          (c) => c.toARGB32() == parsedHex.toARGB32(),
        );
        if (existingIdx != -1) return existingIdx + 1;
        palette.add(parsedHex);
        return palette.length;
      }

      warnings.add('Unknown color "$raw"; using fallback index $fallback.');
      return fallback;
    }

    final grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));

    // Optional base template
    final templateId = spec['template'] as String?;
    if (templateId != null && templateId.isNotEmpty) {
      final tmpl = SpriteTemplate.getById(templateId);
      if (tmpl != null) {
        final tGrid = tmpl.parseToGrid();
        _blitGrid(grid, tGrid, gridSize);
      } else {
        warnings.add('Unknown template "$templateId".');
      }
    }

    // 2. Render layers bottom-to-top
    final layers = spec['layers'] as List? ?? const [];
    for (int i = 0; i < layers.length; i++) {
      final rawLayer = layers[i];
      if (rawLayer is! Map<String, dynamic>) {
        warnings.add('Layer $i is not an object; skipped.');
        continue;
      }
      if (rawLayer['visible'] == false) continue;

      final layerName = (rawLayer['name'] as String?) ?? 'layer_$i';
      final layerGrid = List.generate(
        gridSize,
        (_) => List.filled(gridSize, 0),
      );

      final NormalizedRect? boundsRect = _parseBounds(
        rawLayer['bounds'],
        gridSize,
      );
      final BoundedCanvas? bounded = boundsRect != null
          ? BoundedCanvas(
              grid: layerGrid,
              boundingBox: boundsRect,
              gridSize: gridSize,
            )
          : null;

      void applyOps(List<dynamic> opsList, {bool maskMode = false}) {
        for (final rawOp in opsList) {
          if (rawOp is! Map<String, dynamic>) continue;
          final tool = (rawOp['tool'] as String? ?? '').trim().toLowerCase();
          if (tool.isEmpty) continue;
          final params = _parseNumList(rawOp['params']);
          final colorIdx = maskMode
              ? (rawOp.containsKey('color')
                    ? resolveColor(rawOp['color'], fallback: 1)
                    : 1)
              : resolveColor(
                  rawOp['color'] ?? rawOp['colorIndex'],
                  fallback: 1,
                );

          final cmd = DrawingCommandFactory.create(tool, params);
          if (cmd == null) {
            warnings.add(
              'Layer "$layerName": invalid command "$tool" with params $params.',
            );
            continue;
          }
          if (bounded != null) {
            bounded.executeClamped((g) => cmd.execute(g, colorIdx, gridSize));
          } else {
            cmd.execute(layerGrid, colorIdx, gridSize);
          }
        }
      }

      // Mode A: Component mask mode (shapes/maskOps + fill/fill2/gradientAngle/outline)
      final hasMaskSpec =
          rawLayer.containsKey('maskOps') ||
          rawLayer.containsKey('shapes') ||
          rawLayer.containsKey('fill') ||
          rawLayer.containsKey('fillColor');

      if (hasMaskSpec) {
        final maskGrid = List.generate(
          gridSize,
          (_) => List.filled(gridSize, 0),
        );
        final maskBounded = boundsRect != null
            ? BoundedCanvas(
                grid: maskGrid,
                boundingBox: boundsRect,
                gridSize: gridSize,
              )
            : null;

        final maskOps =
            (rawLayer['maskOps'] ?? rawLayer['shapes']) as List? ?? const [];
        for (final rawOp in maskOps) {
          if (rawOp is! Map<String, dynamic>) continue;
          final tool = (rawOp['tool'] as String? ?? '').trim().toLowerCase();
          if (tool.isEmpty) continue;
          final params = _parseNumList(rawOp['params']);
          final val = rawOp['erase'] == true ? 0 : 1;
          final cmd = DrawingCommandFactory.create(tool, params);
          if (cmd == null) {
            warnings.add(
              'Layer "$layerName": invalid mask command "$tool" with params $params.',
            );
            continue;
          }
          if (maskBounded != null) {
            maskBounded.executeClamped((g) => cmd.execute(g, val, gridSize));
          } else {
            cmd.execute(maskGrid, val, gridSize);
          }
        }

        _applyCoordList(
          maskGrid,
          rawLayer['add'] as List?,
          1,
          gridSize,
          maskBounded,
          warnings,
          layerName,
        );
        _applyCoordList(
          maskGrid,
          (rawLayer['remove'] ?? rawLayer['erase']) as List?,
          0,
          gridSize,
          maskBounded,
          warnings,
          layerName,
        );

        if (rawLayer['mirrorH'] == true) {
          MirrorHorizontalCommand().execute(maskGrid, 1, gridSize);
        }
        if (rawLayer['mirrorV'] == true) {
          MirrorVerticalCommand().execute(maskGrid, 1, gridSize);
        }

        final fillRaw = rawLayer['fill'] ?? rawLayer['fillColor'];
        final fill2Raw = rawLayer['fill2'] ?? rawLayer['fillColor2'];
        final outlineRaw = rawLayer['outline'] ?? rawLayer['outlineColor'];
        final outlineMode = (rawLayer['outlineMode'] as String? ?? 'inner')
            .trim()
            .toLowerCase();
        final double gradientAngle =
            (_parseNum(rawLayer['gradientAngle']) ?? 90.0).toDouble();
        final bool dither = rawLayer['dither'] != false;

        final fillIdx = fillRaw != null
            ? resolveColor(fillRaw, fallback: 1)
            : 0;
        final fill2Idx = fill2Raw != null
            ? resolveColor(fill2Raw, fallback: 0)
            : 0;
        final outlineIdx = outlineRaw != null
            ? resolveColor(outlineRaw, fallback: 0)
            : 0;

        final comp = PixelArtComponent(
          name: layerName,
          description: (rawLayer['description'] as String?) ?? '',
          relativeBoundingBox: boundsRect ?? NormalizedRect.full,
          grid: maskGrid,
          fillColor: fillIdx > 0 ? palette[fillIdx - 1] : null,
          fillColor2: fill2Idx > 0 ? palette[fill2Idx - 1] : null,
          gradientAngle: gradientAngle,
          outlineColor: outlineIdx > 0 ? palette[outlineIdx - 1] : null,
          isSculpted: true,
        );

        if (fillIdx > 0) {
          final color1 = palette[fillIdx - 1];
          for (int y = 0; y < gridSize; y++) {
            for (int x = 0; x < gridSize; x++) {
              if (maskGrid[y][x] > 0) {
                final c = comp.getPixelFillColorWithMode(x, y, dither: dither);
                if (c != null) {
                  layerGrid[y][x] = (fill2Idx > 0 && c != color1)
                      ? fill2Idx
                      : fillIdx;
                }
              }
            }
          }
        }

        if (outlineIdx > 0) {
          if (outlineMode == 'outer' || outlineMode == 'outer8') {
            OutlineCommand(
              eightConnected: outlineMode == 'outer8',
            ).execute(layerGrid, outlineIdx, gridSize);
          } else {
            final outline = comp.getOutlineGrid();
            if (outline != null) {
              for (int y = 0; y < gridSize; y++) {
                for (int x = 0; x < gridSize; x++) {
                  if (outline[y][x] > 0) {
                    layerGrid[y][x] = outlineIdx;
                  }
                }
              }
            }
          }
        }
      }

      // Mode B: Direct ASCII rows (optionally with custom char->color legend)
      final rawRows = rawLayer['rows'] as List?;
      if (rawRows != null && rawRows.isNotEmpty) {
        final lines = rawRows.map((e) => e.toString()).toList();
        final offsetX = _parseInt(rawLayer['offsetX']) ?? 0;
        final offsetY = _parseInt(rawLayer['offsetY']) ?? 0;
        final rawLegend = rawLayer['legend'] as Map<String, dynamic>?;
        final legend = <String, int>{};
        if (rawLegend != null) {
          for (final entry in rawLegend.entries) {
            if (entry.key.isNotEmpty) {
              legend[entry.key[0]] = resolveColor(entry.value, fallback: 0);
            }
          }
        }

        for (int ry = 0; ry < lines.length; ry++) {
          final line = lines[ry];
          for (int rx = 0; rx < line.length; rx++) {
            final ch = line[rx];
            if (ch == '.' || ch == ' ') continue;
            int idx;
            if (legend.containsKey(ch)) {
              idx = legend[ch]!;
            } else if (ch == '0') {
              idx = 0;
            } else {
              final digit = int.tryParse(ch);
              if (digit != null) {
                idx = digit;
              } else {
                final code = ch.toUpperCase().codeUnitAt(0);
                if (code >= 65 && code <= 90) {
                  idx = code - 65 + 10;
                } else {
                  idx = 1;
                }
              }
            }

            final tx = rx + offsetX;
            final ty = ry + offsetY;
            if (tx >= 0 && tx < gridSize && ty >= 0 && ty < gridSize) {
              if (idx == 0) {
                layerGrid[ty][tx] = 0;
              } else if (idx <= palette.length) {
                layerGrid[ty][tx] = idx;
              } else {
                warnings.add(
                  'Layer "$layerName": row char "$ch" resolved to out-of-range color index $idx.',
                );
              }
            }
          }
        }
      }

      // Mode C: Direct multi-color ops
      final ops = rawLayer['ops'] as List?;
      if (ops != null && ops.isNotEmpty) {
        applyOps(ops, maskMode: false);
      }

      // Per-layer mirror (when not already applied in mask-only path)
      if (!hasMaskSpec) {
        if (rawLayer['mirrorH'] == true) {
          MirrorHorizontalCommand().execute(layerGrid, 0, gridSize);
        }
        if (rawLayer['mirrorV'] == true) {
          MirrorVerticalCommand().execute(layerGrid, 0, gridSize);
        }
      }

      // Composite layer onto main grid (0 = transparent)
      final eraseMode = rawLayer['blend'] == 'erase';
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          final v = layerGrid[y][x];
          if (v > 0) {
            grid[y][x] = eraseMode ? 0 : v;
          }
        }
      }
    }

    // 3. Global postOps (refinements, outer silhouette outline, global mirror, pixel tweaks)
    final postOps = spec['postOps'] as List? ?? const [];
    for (final rawOp in postOps) {
      if (rawOp is! Map<String, dynamic>) continue;
      final tool = (rawOp['tool'] as String? ?? '').trim().toLowerCase();
      if (tool.isEmpty) continue;
      final params = _parseNumList(rawOp['params']);
      final colorIdx = resolveColor(
        rawOp['color'] ?? rawOp['colorIndex'],
        fallback: 1,
      );
      final cmd = DrawingCommandFactory.create(tool, params);
      if (cmd == null) {
        warnings.add('postOps: invalid command "$tool" with params $params.');
        continue;
      }
      cmd.execute(grid, colorIdx, gridSize);
    }

    // Scene-level symmetry shortcuts
    if (spec['mirrorH'] == true) {
      MirrorHorizontalCommand().execute(grid, 0, gridSize);
    }
    if (spec['mirrorV'] == true) {
      MirrorVerticalCommand().execute(grid, 0, gridSize);
    }

    return SceneRenderResult(
      title: title,
      gridSize: gridSize,
      palette: palette,
      colorNames: colorNames,
      grid: grid,
      warnings: warnings,
    );
  }

  static void _parsePalette(
    dynamic rawPalette,
    List<PixelColor> palette,
    Map<String, int> colorNames,
    List<String> warnings,
  ) {
    if (rawPalette == null) return;

    if (rawPalette is String) {
      final preset = PaletteRegistry.findById(rawPalette);
      if (preset != null) {
        palette.addAll(preset.colors);
      } else {
        warnings.add('Unknown palette preset "$rawPalette".');
      }
      return;
    }

    if (rawPalette is List) {
      for (final item in rawPalette) {
        if (item is String) {
          final c = PixelColor.tryParseHex(item);
          if (c != null) {
            palette.add(c);
          } else {
            warnings.add('Invalid hex color in palette: "$item".');
          }
        } else if (item is Map<String, dynamic>) {
          final name = item['name']?.toString().trim();
          final hex = item['hex']?.toString() ?? item['color']?.toString();
          final c = PixelColor.tryParseHex(hex);
          if (c != null) {
            palette.add(c);
            if (name != null && name.isNotEmpty) {
              colorNames[name.toLowerCase()] = palette.length;
            }
          } else {
            warnings.add('Invalid palette entry: $item');
          }
        }
      }
      return;
    }

    if (rawPalette is Map<String, dynamic>) {
      for (final entry in rawPalette.entries) {
        final c = PixelColor.tryParseHex(entry.value?.toString());
        if (c != null) {
          palette.add(c);
          colorNames[entry.key.trim().toLowerCase()] = palette.length;
        } else {
          warnings.add(
            'Invalid hex color for "${entry.key}": "${entry.value}".',
          );
        }
      }
    }
  }

  static NormalizedRect? _parseBounds(dynamic raw, int gridSize) {
    if (raw is! Map<String, dynamic>) return null;
    if (raw.containsKey('left') || raw.containsKey('width')) {
      return NormalizedRect.fromJson(raw);
    }
    if (raw.containsKey('minX') && raw.containsKey('maxX')) {
      final minX = _parseInt(raw['minX']) ?? 0;
      final maxX = _parseInt(raw['maxX']) ?? (gridSize - 1);
      final minY = _parseInt(raw['minY']) ?? 0;
      final maxY = _parseInt(raw['maxY']) ?? (gridSize - 1);
      return NormalizedRect.fromLTWH(
        minX / gridSize,
        minY / gridSize,
        (maxX - minX + 1) / gridSize,
        (maxY - minY + 1) / gridSize,
      );
    }
    return null;
  }

  static void _applyCoordList(
    List<List<int>> grid,
    List<dynamic>? coords,
    int value,
    int gridSize,
    BoundedCanvas? bounded,
    List<String> warnings,
    String layerName,
  ) {
    if (coords == null) return;
    for (final item in coords) {
      int? x, y;
      if (item is List && item.length >= 2) {
        x = _parseInt(item[0]);
        y = _parseInt(item[1]);
      } else if (item is Map) {
        x = _parseInt(item['x']);
        y = _parseInt(item['y']);
      }
      if (x == null || y == null) continue;
      if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) {
        warnings.add('Layer "$layerName": coord ($x,$y) out of grid bounds.');
        continue;
      }
      if (bounded != null) {
        bounded.setPixel(x, y, value);
      } else {
        grid[y][x] = value;
      }
    }
  }

  static void _blitGrid(
    List<List<int>> dst,
    List<List<int>> src,
    int gridSize,
  ) {
    for (int y = 0; y < src.length && y < gridSize; y++) {
      for (int x = 0; x < src[y].length && x < gridSize; x++) {
        if (src[y][x] > 0) {
          dst[y][x] = src[y][x];
        }
      }
    }
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static num? _parseNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  static List<num> _parseNumList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <num>[];
    for (final e in raw) {
      final n = _parseNum(e);
      if (n != null) out.add(n);
    }
    return out;
  }
}
