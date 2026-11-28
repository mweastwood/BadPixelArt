import 'dart:typed_data';

import 'png_encoder.dart';
import 'types.dart';

/// Renders an upscaled inspection PNG with checkerboard transparency,
/// pixel gridlines, coordinate rulers (0..W-1, 0..H-1), and a palette swatch bar.
///
/// Designed specifically so humans and multimodal agents can visually inspect
/// a pixel art canvas and immediately read exact `(x, y)` coordinates and
/// palette indices.
class PreviewRenderer {
  /// Minimal 3x5 bitmap font for digits 0-9 and uppercase A-Z.
  static const Map<String, List<String>> _font3x5 = {
    '0': ['111', '101', '101', '101', '111'],
    '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'],
    '3': ['111', '001', '111', '001', '111'],
    '4': ['101', '101', '111', '001', '001'],
    '5': ['111', '100', '111', '001', '111'],
    '6': ['111', '100', '111', '101', '111'],
    '7': ['111', '001', '001', '010', '010'],
    '8': ['111', '101', '111', '101', '111'],
    '9': ['111', '101', '111', '001', '111'],
    'A': ['010', '101', '111', '101', '101'],
    'B': ['110', '101', '110', '101', '110'],
    'C': ['011', '100', '100', '100', '011'],
    'D': ['110', '101', '101', '101', '110'],
    'E': ['111', '100', '110', '100', '111'],
    'F': ['111', '100', '110', '100', '100'],
    'G': ['011', '100', '101', '101', '011'],
    'H': ['101', '101', '111', '101', '101'],
    'I': ['111', '010', '010', '010', '111'],
    'J': ['001', '001', '001', '101', '010'],
    'K': ['101', '101', '110', '101', '101'],
    'L': ['100', '100', '100', '100', '111'],
    'M': ['101', '111', '111', '101', '101'],
    'N': ['111', '101', '101', '101', '101'],
    'O': ['010', '101', '101', '101', '010'],
    'P': ['110', '101', '110', '100', '100'],
    'Q': ['010', '101', '101', '111', '011'],
    'R': ['110', '101', '110', '101', '101'],
    'S': ['011', '100', '010', '001', '110'],
    'T': ['111', '010', '010', '010', '010'],
    'U': ['101', '101', '101', '101', '111'],
    'V': ['101', '101', '101', '101', '010'],
    'W': ['101', '101', '111', '111', '101'],
    'X': ['101', '101', '010', '101', '101'],
    'Y': ['101', '101', '010', '010', '010'],
    'Z': ['111', '001', '010', '100', '111'],
  };

  /// Renders a debug preview PNG with rulers, gridlines, and palette legend.
  static Uint8List renderPreviewPng(
    List<List<int>> grid,
    List<PixelColor> palette, {
    int cellSize = 20,
    bool showGridLines = true,
    bool showRulers = true,
    bool showPaletteBar = true,
  }) {
    final int gridH = grid.length;
    final int gridW = gridH > 0 ? grid[0].length : 0;
    if (gridW <= 0 || gridH <= 0 || cellSize < 4) {
      return Uint8List(0);
    }

    final int rulerLeft = showRulers ? 28 : 0;
    final int rulerTop = showRulers ? 22 : 0;
    final int rightPad = 8;
    final int bottomPad = 8;
    final int paletteBarHeight = (showPaletteBar && palette.isNotEmpty)
        ? 38
        : 0;

    final int canvasW = gridW * cellSize;
    final int canvasH = gridH * cellSize;
    final int totalW = rulerLeft + canvasW + rightPad;
    final int totalH = rulerTop + canvasH + bottomPad + paletteBarHeight;

    final buf = _RgbaBuffer(totalW, totalH);
    const frameBg = PixelColor(0xFF1A1D24);
    const rulerText = PixelColor(0xFFB8C4D4);
    const checkerA = PixelColor(0xFF2B2F3A);
    const checkerB = PixelColor(0xFF343946);
    const minorGrid = PixelColor(0xFF474E61);
    const majorGrid = PixelColor(0xFF67718A);

    buf.fillRect(0, 0, totalW, totalH, frameBg);

    // Draw pixels + checkerboard background
    final int checkerTile = (cellSize ~/ 2).clamp(2, 12);
    for (int gy = 0; gy < gridH; gy++) {
      final row = grid[gy];
      for (int gx = 0; gx < gridW; gx++) {
        final px0 = rulerLeft + gx * cellSize;
        final py0 = rulerTop + gy * cellSize;
        final idx = gx < row.length ? row[gx] : 0;

        if (idx > 0 && idx <= palette.length) {
          final color = palette[idx - 1];
          if (color.a == 255) {
            buf.fillRect(px0, py0, cellSize, cellSize, color);
          } else {
            _fillChecker(
              buf,
              px0,
              py0,
              cellSize,
              cellSize,
              checkerTile,
              checkerA,
              checkerB,
            );
            buf.blendRect(px0, py0, cellSize, cellSize, color);
          }
        } else {
          _fillChecker(
            buf,
            px0,
            py0,
            cellSize,
            cellSize,
            checkerTile,
            checkerA,
            checkerB,
          );
        }
      }
    }

    // Draw gridlines
    if (showGridLines) {
      for (int gx = 0; gx <= gridW; gx++) {
        final x = rulerLeft + gx * cellSize;
        final isMajor = gx % 4 == 0 || gx == gridW;
        final lineColor = isMajor ? majorGrid : minorGrid;
        final drawX = gx == gridW ? x - 1 : x;
        buf.fillRect(drawX, rulerTop, 1, canvasH, lineColor);
      }
      for (int gy = 0; gy <= gridH; gy++) {
        final y = rulerTop + gy * cellSize;
        final isMajor = gy % 4 == 0 || gy == gridH;
        final lineColor = isMajor ? majorGrid : minorGrid;
        final drawY = gy == gridH ? y - 1 : y;
        buf.fillRect(rulerLeft, drawY, canvasW, 1, lineColor);
      }
    }

    // Draw coordinate rulers
    if (showRulers) {
      final fontScale = cellSize >= 18 ? 2 : 1;
      final stepX = cellSize < 14 ? 2 : 1;
      final stepY = cellSize < 12 ? 2 : 1;

      for (int gx = 0; gx < gridW; gx += stepX) {
        final label = gx.toString();
        final textW = _measureText(label, fontScale);
        final textH = 5 * fontScale;
        final cx = rulerLeft + gx * cellSize + (cellSize - textW) ~/ 2;
        final cy = (rulerTop - textH) ~/ 2;
        _drawText(buf, label, cx, cy, fontScale, rulerText);
      }

      for (int gy = 0; gy < gridH; gy += stepY) {
        final label = gy.toString();
        final textW = _measureText(label, fontScale);
        final textH = 5 * fontScale;
        final cx = rulerLeft - textW - 4;
        final cy = rulerTop + gy * cellSize + (cellSize - textH) ~/ 2;
        _drawText(buf, label, cx, cy, fontScale, rulerText);
      }
    }

    // Draw palette swatch bar
    if (showPaletteBar && palette.isNotEmpty) {
      final barTop = rulerTop + canvasH + bottomPad + 4;
      final count = palette.length;
      final availW = canvasW;
      final swatchStep = (availW ~/ count).clamp(12, 34);
      final swatchW = (swatchStep - 3).clamp(8, 28);
      final swatchH = 16;

      for (int i = 0; i < count; i++) {
        final sx = rulerLeft + i * swatchStep;
        if (sx + swatchW > totalW - rightPad) break;

        // Border around swatch
        buf.fillRect(sx - 1, barTop - 1, swatchW + 2, swatchH + 2, majorGrid);
        buf.fillRect(sx, barTop, swatchW, swatchH, palette[i]);

        final label = indexToSymbol(i + 1);
        final tw = _measureText(label, 2);
        final lx = sx + (swatchW - tw) ~/ 2;
        _drawText(buf, label, lx, barTop + swatchH + 3, 2, rulerText);
      }
    }

    return PngEncoder.encodeRgba(totalW, totalH, buf.data);
  }

  /// Maps a 1-based color index to a single display character (`1..9`, `A..Z`).
  static String indexToSymbol(int index) {
    if (index <= 0) return '.';
    if (index <= 9) return index.toString();
    if (index <= 35) return String.fromCharCode(65 + index - 10);
    return '#';
  }

  /// Formats a pixel grid as a readable ASCII table with coordinate rulers.
  static String formatAsciiGrid(List<List<int>> grid) {
    final int height = grid.length;
    final int width = height > 0 ? grid[0].length : 0;
    if (width == 0 || height == 0) return '(empty grid)';

    final sb = StringBuffer();
    // Tens header for widths > 10
    if (width > 10) {
      sb.write('    ');
      for (int x = 0; x < width; x++) {
        sb.write(x >= 10 ? '${x ~/ 10} ' : '  ');
      }
      sb.writeln();
    }
    sb.write('    ');
    for (int x = 0; x < width; x++) {
      sb.write('${x % 10} ');
    }
    sb.writeln();

    for (int y = 0; y < height; y++) {
      sb.write('${y.toString().padLeft(2)}  ');
      final row = grid[y];
      for (int x = 0; x < width; x++) {
        final v = x < row.length ? row[x] : 0;
        sb.write('${indexToSymbol(v)} ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  static void _fillChecker(
    _RgbaBuffer buf,
    int x0,
    int y0,
    int w,
    int h,
    int tile,
    PixelColor a,
    PixelColor b,
  ) {
    for (int y = y0; y < y0 + h; y++) {
      final ty = (y - y0) ~/ tile;
      for (int x = x0; x < x0 + w; x++) {
        final tx = (x - x0) ~/ tile;
        buf.setPixel(x, y, ((tx + ty) & 1) == 0 ? a : b);
      }
    }
  }

  static int _measureText(String text, int scale) {
    if (text.isEmpty) return 0;
    return (text.length * 4 - 1) * scale;
  }

  static void _drawText(
    _RgbaBuffer buf,
    String text,
    int x,
    int y,
    int scale,
    PixelColor color,
  ) {
    int cursorX = x;
    for (int i = 0; i < text.length; i++) {
      final glyph = _font3x5[text[i].toUpperCase()];
      if (glyph != null) {
        for (int gy = 0; gy < 5; gy++) {
          final row = glyph[gy];
          for (int gx = 0; gx < 3; gx++) {
            if (row[gx] == '1') {
              buf.fillRect(
                cursorX + gx * scale,
                y + gy * scale,
                scale,
                scale,
                color,
              );
            }
          }
        }
      }
      cursorX += 4 * scale;
    }
  }
}

class _RgbaBuffer {
  final int width;
  final int height;
  final Uint8List data;

  _RgbaBuffer(this.width, this.height) : data = Uint8List(width * height * 4);

  void setPixel(int x, int y, PixelColor c) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final off = (y * width + x) * 4;
    data[off] = c.r;
    data[off + 1] = c.g;
    data[off + 2] = c.b;
    data[off + 3] = c.a;
  }

  void fillRect(int x0, int y0, int w, int h, PixelColor c) {
    final xStart = x0 < 0 ? 0 : x0;
    final yStart = y0 < 0 ? 0 : y0;
    final xEnd = (x0 + w) > width ? width : (x0 + w);
    final yEnd = (y0 + h) > height ? height : (y0 + h);
    for (int y = yStart; y < yEnd; y++) {
      int off = (y * width + xStart) * 4;
      for (int x = xStart; x < xEnd; x++) {
        data[off] = c.r;
        data[off + 1] = c.g;
        data[off + 2] = c.b;
        data[off + 3] = c.a;
        off += 4;
      }
    }
  }

  void blendRect(int x0, int y0, int w, int h, PixelColor c) {
    if (c.a == 0) return;
    final alpha = c.a / 255.0;
    final inv = 1.0 - alpha;
    final xStart = x0 < 0 ? 0 : x0;
    final yStart = y0 < 0 ? 0 : y0;
    final xEnd = (x0 + w) > width ? width : (x0 + w);
    final yEnd = (y0 + h) > height ? height : (y0 + h);
    for (int y = yStart; y < yEnd; y++) {
      int off = (y * width + xStart) * 4;
      for (int x = xStart; x < xEnd; x++) {
        data[off] = (c.r * alpha + data[off] * inv).round().clamp(0, 255);
        data[off + 1] = (c.g * alpha + data[off + 1] * inv).round().clamp(
          0,
          255,
        );
        data[off + 2] = (c.b * alpha + data[off + 2] * inv).round().clamp(
          0,
          255,
        );
        data[off + 3] = 255;
        off += 4;
      }
    }
  }
}
