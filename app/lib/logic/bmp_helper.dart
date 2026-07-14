// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'dart:ui';

/// Generates a 24-bit BMP image from a grid of color indices.
Uint8List generateBmp(List<List<int>> grid, List<Color> palette) {
  final int height = grid.length;
  final int width = grid.isNotEmpty ? grid[0].length : 0;
  if (width == 0 || height == 0) {
    return generateBmpFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
  }
  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  final int rowStride = width * bytesPerPixel + rowPadding;
  final int pixelDataSize = rowStride * height;
  final int fileSize = 54 + pixelDataSize;

  final Uint8List bmp = Uint8List(fileSize);
  final ByteData bd = ByteData.sublistView(bmp);

  // BMP Header
  bmp[0] = 0x42; // 'B'
  bmp[1] = 0x4D; // 'M'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(6, 0, Endian.little);
  bd.setUint32(10, 54, Endian.little);

  // DIB Header (BITMAPINFOHEADER)
  bd.setUint32(14, 40, Endian.little);
  bd.setUint32(18, width, Endian.little);
  bd.setUint32(22, height, Endian.little);
  bd.setUint16(26, 1, Endian.little);
  bd.setUint16(28, 24, Endian.little); // 24-bit BGR
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little); // 72 DPI
  bd.setUint32(42, 2835, Endian.little); // 72 DPI
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = height - 1; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      final colorIndex = grid[y][x];
      final color = colorIndex == 0
          ? ((x + y) % 2 == 0
                ? const Color(0xFF262626)
                : const Color(0xFF1E1E1E))
          : palette[colorIndex - 1];

      bmp[offset] = color.blue;
      bmp[offset + 1] = color.green;
      bmp[offset + 2] = color.red;
      offset += 3;
    }
    for (int p = 0; p < rowPadding; p++) {
      bmp[offset++] = 0;
    }
  }

  return bmp;
}

/// Combines multiple BMP files into a 2x2 grid.
Uint8List combineBmps(List<Uint8List> bmps) {
  final activeBmps = bmps.where((b) => b.isNotEmpty).toList();
  if (activeBmps.isEmpty) {
    return generateBmpFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
  }

  final int n = activeBmps.length;
  final ByteData firstBd = ByteData.sublistView(activeBmps[0]);
  final int panelSize = firstBd.getUint32(18, Endian.little);

  final int cols = n <= 1 ? 1 : 2;
  final int rows = n <= 1 ? 1 : 2;

  final int combinedWidth = panelSize * cols;
  final int combinedHeight = panelSize * rows;
  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (combinedWidth * bytesPerPixel) % 4) % 4;
  final int rowStride = combinedWidth * bytesPerPixel + rowPadding;
  final int pixelDataSize = rowStride * combinedHeight;
  final int fileSize = 54 + pixelDataSize;

  final Uint8List combined = Uint8List(fileSize);
  final ByteData bd = ByteData.sublistView(combined);

  // BMP Header
  combined[0] = 0x42; // 'B'
  combined[1] = 0x4D; // 'M'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(6, 0, Endian.little);
  bd.setUint32(10, 54, Endian.little);

  // DIB Header (BITMAPINFOHEADER)
  bd.setUint32(14, 40, Endian.little);
  bd.setUint32(18, combinedWidth, Endian.little);
  bd.setUint32(22, combinedHeight, Endian.little);
  bd.setUint16(26, 1, Endian.little);
  bd.setUint16(28, 24, Endian.little); // 24-bit BGR
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little); // 72 DPI
  bd.setUint32(42, 2835, Endian.little); // 72 DPI
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = combinedHeight - 1; y >= 0; y--) {
    final int gridRow = y ~/ panelSize;
    final int panelY = (gridRow + 1) * panelSize - 1 - y;

    for (int gridCol = 0; gridCol < cols; gridCol++) {
      final int panelIndex = gridRow * cols + gridCol;
      if (panelIndex < n) {
        final bmpBytes = activeBmps[panelIndex];
        final int srcRowOffset = 54 + panelY * panelSize * 3;
        for (int x = 0; x < panelSize; x++) {
          final int pixelOffset = srcRowOffset + x * 3;
          combined[offset] = bmpBytes[pixelOffset]; // blue
          combined[offset + 1] = bmpBytes[pixelOffset + 1]; // green
          combined[offset + 2] = bmpBytes[pixelOffset + 2]; // red
          offset += 3;
        }
      } else {
        // Write black filler pixels
        for (int x = 0; x < panelSize; x++) {
          combined[offset] = 0;
          combined[offset + 1] = 0;
          combined[offset + 2] = 0;
          offset += 3;
        }
      }
    }

    for (int pad = 0; pad < rowPadding; pad++) {
      combined[offset++] = 0;
    }
  }

  return combined;
}

/// Generates a BMP file header and structure from raw RGBA bytes.
Uint8List generateBmpFromRgba(Uint8List rgbaBytes, int width, int height) {
  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  final int rowStride = width * bytesPerPixel + rowPadding;
  final int pixelDataSize = rowStride * height;
  final int fileSize = 54 + pixelDataSize;

  final Uint8List bmp = Uint8List(fileSize);
  final ByteData bd = ByteData.sublistView(bmp);

  bmp[0] = 0x42; // 'B'
  bmp[1] = 0x4D; // 'M'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(6, 0, Endian.little);
  bd.setUint32(10, 54, Endian.little);

  bd.setUint32(14, 40, Endian.little);
  bd.setUint32(18, width, Endian.little);
  bd.setUint32(22, height, Endian.little);
  bd.setUint16(26, 1, Endian.little);
  bd.setUint16(28, 24, Endian.little); // 24-bit BGR
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little); // 72 DPI
  bd.setUint32(42, 2835, Endian.little); // 72 DPI
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = height - 1; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      final int rgbaOffset = (y * width + x) * 4;
      final int r = rgbaBytes[rgbaOffset];
      final int g = rgbaBytes[rgbaOffset + 1];
      final int b = rgbaBytes[rgbaOffset + 2];

      bmp[offset] = b;
      bmp[offset + 1] = g;
      bmp[offset + 2] = r;
      offset += 3;
    }
    for (int p = 0; p < rowPadding; p++) {
      bmp[offset++] = 0;
    }
  }

  return bmp;
}
