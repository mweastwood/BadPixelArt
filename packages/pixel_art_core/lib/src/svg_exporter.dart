import 'types.dart';

/// Generates an SVG vector string representation of the pixel art [grid] and [palette].
///
/// Optimizes horizontal spans of identical colors into single rectangle elements
/// with crisp pixel edges (`shape-rendering="crispEdges"`).
String generateSvgString(
  List<List<int>> grid,
  List<PixelColor> palette, {
  int scale = 1,
  bool transparentBackground = true,
  PixelColor backgroundColor = const PixelColor(0xFF1E1E1E),
}) {
  final int height = grid.length;
  final int width = height > 0 ? grid[0].length : 0;
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
    final bgHex = backgroundColor.toHex();
    buffer.writeln('  <rect width="100%" height="100%" fill="$bgHex" />');
  }

  for (int y = 0; y < height; y++) {
    final row = grid[y];
    int x = 0;
    while (x < width && x < row.length) {
      final colorIndex = row[x];
      if (colorIndex > 0 && colorIndex <= palette.length) {
        int runLength = 1;
        while (x + runLength < width &&
            x + runLength < row.length &&
            row[x + runLength] == colorIndex) {
          runLength++;
        }
        final color = palette[colorIndex - 1];
        if (color.a > 0) {
          final hex = color.toHex();
          if (color.a < 255) {
            final double opacity = color.a / 255.0;
            final opacityStr = opacity
                .toStringAsFixed(4)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), '');
            buffer.writeln(
              '  <rect x="$x" y="$y" width="$runLength" height="1" fill="$hex" fill-opacity="$opacityStr" />',
            );
          } else {
            buffer.writeln(
              '  <rect x="$x" y="$y" width="$runLength" height="1" fill="$hex" />',
            );
          }
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
