import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

extension ColorRgbInt on Color {
  int get rInt => (r * 255.0).round().clamp(0, 255);
  int get gInt => (g * 255.0).round().clamp(0, 255);
  int get bInt => (b * 255.0).round().clamp(0, 255);
}

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

      bmp[offset] = color.bInt;
      bmp[offset + 1] = color.gInt;
      bmp[offset + 2] = color.rInt;
      offset += 3;
    }
    for (int p = 0; p < rowPadding; p++) {
      bmp[offset++] = 0;
    }
  }

  return bmp;
}

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

Future<Uint8List?> resizeAndConvertToBmp(
  Uint8List imageBytes,
  int gridSize,
) async {
  try {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frameInfo = await codec.getNextFrame();
    final originalImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, gridSize.toDouble(), gridSize.toDouble()),
      image: originalImage,
      fit: BoxFit.cover,
    );

    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(gridSize, gridSize);

    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return null;

    final rgbaBytes = byteData.buffer.asUint8List();
    return generateBmpFromRgba(rgbaBytes, gridSize, gridSize);
  } catch (e) {
    debugPrint('Error resizing image: $e');
    return null;
  }
}

Uint8List generateBmpFromRgba(Uint8List rgbaBytes, int width, int height) {
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

List<List<Color>> bmpToColorGrid(Uint8List bmpBytes) {
  final ByteData bd = ByteData.sublistView(bmpBytes);
  final int size = bd.getUint32(18, Endian.little);
  final List<List<Color>> grid = List.generate(
    size,
    (_) => List.filled(size, const Color(0xFF000000)),
  );
  if (bmpBytes.length >= 54 + size * size * 3) {
    int offset = 54;
    for (int y = size - 1; y >= 0; y--) {
      for (int x = 0; x < size; x++) {
        final b = bmpBytes[offset];
        final g = bmpBytes[offset + 1];
        final r = bmpBytes[offset + 2];
        grid[y][x] = Color(0xFF000000 | (r << 16) | (g << 8) | b);
        offset += 3;
      }
    }
  }
  return grid;
}

Uint8List bmpFromColorGrid(List<List<Color>> grid) {
  final int height = grid.length;
  final int width = grid.isNotEmpty ? grid[0].length : 0;
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
  bd.setUint16(28, 24, Endian.little);
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little);
  bd.setUint32(42, 2835, Endian.little);
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = height - 1; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      final color = grid[y][x];
      bmp[offset] = color.bInt;
      bmp[offset + 1] = color.gInt;
      bmp[offset + 2] = color.rInt;
      offset += 3;
    }
    for (int p = 0; p < rowPadding; p++) {
      bmp[offset++] = 0;
    }
  }
  return bmp;
}

List<List<Color>> applyGaussianBlur(List<List<Color>> src) {
  final int size = src.length;
  final List<List<Color>> dest = List.generate(
    size,
    (_) => List.filled(size, const Color(0xFF000000)),
  );
  final List<int> kernel = [1, 2, 1, 2, 4, 2, 1, 2, 1];
  const int kernelWeight = 16;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      int sumR = 0;
      int sumG = 0;
      int sumB = 0;

      for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
          final px = (x + kx).clamp(0, size - 1);
          final py = (y + ky).clamp(0, size - 1);
          final color = src[py][px];
          final weight = kernel[(ky + 1) * 3 + (kx + 1)];
          sumR += color.rInt * weight;
          sumG += color.gInt * weight;
          sumB += color.bInt * weight;
        }
      }

      dest[y][x] = Color.fromARGB(
        255,
        (sumR ~/ kernelWeight).clamp(0, 255),
        (sumG ~/ kernelWeight).clamp(0, 255),
        (sumB ~/ kernelWeight).clamp(0, 255),
      );
    }
  }
  return dest;
}

List<List<Color>> applyColorQuantization(
  List<List<Color>> src,
  List<Color> palette,
) {
  final int size = src.length;
  final List<List<Color>> dest = List.generate(
    size,
    (_) => List.filled(size, const Color(0xFF000000)),
  );
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final color = src[y][x];
      Color closestColor = palette.first;
      double minDistance = double.infinity;
      for (final pColor in palette) {
        final dr = color.rInt - pColor.rInt;
        final dg = color.gInt - pColor.gInt;
        final db = color.bInt - pColor.bInt;
        final dist = dr * dr + dg * dg + db * db;
        if (dist < minDistance) {
          minDistance = dist.toDouble();
          closestColor = pColor;
        }
      }
      dest[y][x] = closestColor;
    }
  }
  return dest;
}

List<List<int>> getQuantizedIndexGrid(Uint8List bmpBytes, List<Color> palette) {
  final ByteData bd = ByteData.sublistView(bmpBytes);
  final int size = bd.getUint32(18, Endian.little);
  final List<List<int>> grid = List.generate(size, (_) => List.filled(size, 0));
  if (bmpBytes.length >= 54 + size * size * 3) {
    final refGrid = bmpToColorGrid(bmpBytes);
    final blurredGrid = applyGaussianBlur(refGrid);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final color = blurredGrid[y][x];
        int closestIndex = 0;
        double minDistance = double.infinity;
        for (int i = 0; i < palette.length; i++) {
          final pColor = palette[i];
          final dr = color.rInt - pColor.rInt;
          final dg = color.gInt - pColor.gInt;
          final db = color.bInt - pColor.bInt;
          final dist = dr * dr + dg * dg + db * db;
          if (dist < minDistance) {
            minDistance = dist.toDouble();
            closestIndex = i;
          }
        }
        grid[y][x] = closestIndex + 1;
      }
    }
  }
  return grid;
}

String canvasToTextGrid(List<List<int>> grid) {
  final buffer = StringBuffer();
  final int size = grid.length;

  // Header: 10s digits
  buffer.write('    ');
  for (int x = 0; x < size; x++) {
    buffer.write(x >= 10 ? '${x ~/ 10}' : ' ');
  }
  buffer.write('\n');

  // Header: 1s digits
  buffer.write('    ');
  for (int x = 0; x < size; x++) {
    buffer.write('${x % 10}');
  }
  buffer.write('\n');

  // Rows
  for (int y = 0; y < size; y++) {
    buffer.write('${y.toString().padLeft(3)} ');
    for (int x = 0; x < size; x++) {
      final val = grid[y][x];
      if (val == 0) {
        buffer.write('.');
      } else if (val < 10) {
        buffer.write('$val');
      } else if (val < 36) {
        buffer.write(String.fromCharCode(65 + val - 10)); // A-Z
      } else {
        buffer.write('#');
      }
    }
    buffer.write('\n');
  }

  return buffer.toString();
}

/// Converts image bytes (e.g. BMP, JPEG, WEBP) to PNG bytes (`0x89 0x50 0x4E 0x47`).
/// If [bytes] are already PNG formatted or empty, returns [bytes] directly.
Future<Uint8List> convertToPngBytes(Uint8List bytes) async {
  if (bytes.isEmpty) return bytes;
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return bytes;
  }
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData != null) {
      return byteData.buffer.asUint8List();
    }
  } catch (e) {
    debugPrint('Error converting image to PNG: $e');
  }
  return bytes;
}
