import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

extension ColorRgbInt on Color {
  int get rInt => (toARGB32() >> 16) & 0xFF;
  int get gInt => (toARGB32() >> 8) & 0xFF;
  int get bInt => toARGB32() & 0xFF;
  int get aInt => (toARGB32() >> 24) & 0xFF;
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
      final color = (colorIndex > 0 && colorIndex <= palette.length)
          ? palette[colorIndex - 1]
          : ((x + y) % 2 == 0
                ? const Color(0xFF262626)
                : const Color(0xFF1E1E1E));

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
  final activeBmps = bmps
      .where((b) => b.length >= 54 && b[0] == 0x42 && b[1] == 0x4D)
      .toList();
  if (activeBmps.isEmpty) {
    return generateBmpFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
  }

  final int n = activeBmps.length;
  final ByteData firstBd = ByteData.sublistView(activeBmps[0]);
  final int panelSize = firstBd.getUint32(18, Endian.little);
  if (panelSize <= 0) {
    return generateBmpFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
  }
  final int cols = n <= 1 ? 1 : 2;
  final int rows = n <= 1 ? 1 : 2;

  final int combinedWidth = panelSize * cols;
  final int combinedHeight = panelSize * rows;
  const int bytesPerPixel = 3;
  final int panelRowPadding = (4 - (panelSize * bytesPerPixel) % 4) % 4;
  final int panelStride = panelSize * bytesPerPixel + panelRowPadding;

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
        final int srcRowOffset = 54 + panelY * panelStride;
        for (int x = 0; x < panelSize; x++) {
          final int pixelOffset = srcRowOffset + x * 3;
          if (pixelOffset + 2 < bmpBytes.length) {
            combined[offset] = bmpBytes[pixelOffset]; // blue
            combined[offset + 1] = bmpBytes[pixelOffset + 1]; // green
            combined[offset + 2] = bmpBytes[pixelOffset + 2]; // red
          } else {
            combined[offset] = 0;
            combined[offset + 1] = 0;
            combined[offset + 2] = 0;
          }
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
  ui.Codec? codec;
  ui.Image? originalImage;
  ui.Picture? picture;
  ui.Image? resizedImage;
  try {
    codec = await ui.instantiateImageCodec(imageBytes);
    final frameInfo = await codec.getNextFrame();
    originalImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, gridSize.toDouble(), gridSize.toDouble()),
      image: originalImage,
      fit: BoxFit.cover,
    );

    picture = recorder.endRecording();
    resizedImage = await picture.toImage(gridSize, gridSize);

    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return null;

    final rgbaBytes = byteData.buffer.asUint8List();
    return generateBmpFromRgba(rgbaBytes, gridSize, gridSize);
  } catch (e) {
    debugPrint('Error resizing image: $e');
    return null;
  } finally {
    originalImage?.dispose();
    picture?.dispose();
    resizedImage?.dispose();
    codec?.dispose();
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
  if (bmpBytes.length < 54 || bmpBytes[0] != 0x42 || bmpBytes[1] != 0x4D) {
    return [];
  }
  final ByteData bd = ByteData.sublistView(bmpBytes);
  final int width = bd.getUint32(18, Endian.little);
  final int height = bd.getUint32(22, Endian.little);
  if (width <= 0 || height <= 0) return [];

  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  final int rowStride = width * bytesPerPixel + rowPadding;
  final int expectedDataLength = 54 + rowStride * height;
  if (bmpBytes.length < expectedDataLength) return [];

  final List<List<Color>> grid = List.generate(
    height,
    (_) => List.filled(width, const Color(0xFF000000)),
  );
  int offset = 54;
  for (int y = height - 1; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      final b = bmpBytes[offset];
      final g = bmpBytes[offset + 1];
      final r = bmpBytes[offset + 2];
      grid[y][x] = Color(0xFF000000 | (r << 16) | (g << 8) | b);
      offset += 3;
    }
    offset += rowPadding;
  }
  return grid;
}

/// Directly decodes a BMP into a downscaled 2D Color grid of [targetSize] x [targetSize].
/// Avoids intermediate allocations of large 2D grids and full-resolution Color instances.
List<List<Color>> bmpToDownscaledColorGrid(Uint8List bmpBytes, int targetSize) {
  if (targetSize <= 0 ||
      bmpBytes.length < 54 ||
      bmpBytes[0] != 0x42 ||
      bmpBytes[1] != 0x4D) {
    return [];
  }
  final ByteData bd = ByteData.sublistView(bmpBytes);
  final int width = bd.getUint32(18, Endian.little);
  final int height = bd.getUint32(22, Endian.little);
  if (width <= 0 || height <= 0) return [];

  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  final int rowStride = width * bytesPerPixel + rowPadding;
  final int expectedDataLength = 54 + rowStride * height;
  if (bmpBytes.length < expectedDataLength) return [];

  final double scaleY = height / targetSize;
  final double scaleX = width / targetSize;

  final List<List<Color>> grid = List.generate(
    targetSize,
    (_) => List.filled(targetSize, const Color(0xFF000000)),
  );

  for (int y = 0; y < targetSize; y++) {
    final int srcY = (y * scaleY).toInt().clamp(0, height - 1);
    final int rowOffset = 54 + (height - 1 - srcY) * rowStride;
    for (int x = 0; x < targetSize; x++) {
      final int srcX = (x * scaleX).toInt().clamp(0, width - 1);
      final int pixelOffset = rowOffset + srcX * 3;
      final int b = bmpBytes[pixelOffset];
      final int g = bmpBytes[pixelOffset + 1];
      final int r = bmpBytes[pixelOffset + 2];
      grid[y][x] = Color(0xFF000000 | (r << 16) | (g << 8) | b);
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
  final int height = src.length;
  final int width = src.isNotEmpty ? src[0].length : 0;
  if (height == 0 || width == 0) return [];

  // Pre-extract ARGB integer values for fast bitwise channel extraction.
  final Uint32List srcArgb = Uint32List(height * width);
  for (int y = 0; y < height; y++) {
    final row = src[y];
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      srcArgb[rowOffset + x] = row[x].toARGB32();
    }
  }

  // 1D Horizontal Convolution Pass with kernel [1, 2, 1]
  final Int32List tempR = Int32List(height * width);
  final Int32List tempG = Int32List(height * width);
  final Int32List tempB = Int32List(height * width);

  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      final int xLeft = x > 0 ? x - 1 : 0;
      final int xRight = x < width - 1 ? x + 1 : width - 1;

      final int cLeft = srcArgb[rowOffset + xLeft];
      final int cMid = srcArgb[rowOffset + x];
      final int cRight = srcArgb[rowOffset + xRight];

      final int rL = (cLeft >> 16) & 0xFF;
      final int gL = (cLeft >> 8) & 0xFF;
      final int bL = cLeft & 0xFF;

      final int rM = (cMid >> 16) & 0xFF;
      final int gM = (cMid >> 8) & 0xFF;
      final int bM = cMid & 0xFF;

      final int rR = (cRight >> 16) & 0xFF;
      final int gR = (cRight >> 8) & 0xFF;
      final int bR = cRight & 0xFF;

      final int idx = rowOffset + x;
      tempR[idx] = rL + (rM << 1) + rR;
      tempG[idx] = gL + (gM << 1) + gR;
      tempB[idx] = bL + (bM << 1) + bR;
    }
  }

  // 1D Vertical Convolution Pass with kernel [1, 2, 1] and normalizer (divide by 16)
  final List<List<Color>> dest = List.generate(height, (y) {
    final int yTop = y > 0 ? y - 1 : 0;
    final int yBottom = y < height - 1 ? y + 1 : height - 1;
    final int topOffset = yTop * width;
    final int midOffset = y * width;
    final int bottomOffset = yBottom * width;

    return List.generate(width, (x) {
      final int sumR =
          tempR[topOffset + x] +
          (tempR[midOffset + x] << 1) +
          tempR[bottomOffset + x];
      final int sumG =
          tempG[topOffset + x] +
          (tempG[midOffset + x] << 1) +
          tempG[bottomOffset + x];
      final int sumB =
          tempB[topOffset + x] +
          (tempB[midOffset + x] << 1) +
          tempB[bottomOffset + x];

      return Color.fromARGB(
        255,
        (sumR >> 4).clamp(0, 255),
        (sumG >> 4).clamp(0, 255),
        (sumB >> 4).clamp(0, 255),
      );
    });
  });

  return dest;
}

List<List<Color>> applyColorQuantization(
  List<List<Color>> src,
  List<Color> palette,
) {
  final int height = src.length;
  final int width = src.isNotEmpty ? src[0].length : 0;
  if (height == 0 || width == 0 || palette.isEmpty) return [];
  final List<List<Color>> dest = List.generate(
    height,
    (_) => List.filled(width, const Color(0xFF000000)),
  );
  final paletteRgb = palette
      .map((c) => (r: c.rInt, g: c.gInt, b: c.bInt, color: c))
      .toList();

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final color = src[y][x];
      final cr = color.rInt;
      final cg = color.gInt;
      final cb = color.bInt;
      Color closestColor = paletteRgb.first.color;
      int minDistance = 0x7FFFFFFF;
      for (final p in paletteRgb) {
        final dr = cr - p.r;
        final dg = cg - p.g;
        final db = cb - p.b;
        final dist = dr * dr + dg * dg + db * db;
        if (dist < minDistance) {
          minDistance = dist;
          closestColor = p.color;
        }
      }
      dest[y][x] = closestColor;
    }
  }
  return dest;
}

List<List<int>> getQuantizedIndexGrid(Uint8List bmpBytes, List<Color> palette) {
  final refGrid = bmpToColorGrid(bmpBytes);
  if (refGrid.isEmpty || refGrid[0].isEmpty || palette.isEmpty) {
    return [];
  }
  final int height = refGrid.length;
  final int width = refGrid[0].length;
  final List<List<int>> grid = List.generate(
    height,
    (_) => List.filled(width, 0),
  );
  final blurredGrid = applyGaussianBlur(refGrid);
  final paletteRgb = [
    for (int i = 0; i < palette.length; i++)
      (r: palette[i].rInt, g: palette[i].gInt, b: palette[i].bInt, index: i),
  ];

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final color = blurredGrid[y][x];
      final cr = color.rInt;
      final cg = color.gInt;
      final cb = color.bInt;
      int closestIndex = 0;
      int minDistance = 0x7FFFFFFF;
      for (final p in paletteRgb) {
        final dr = cr - p.r;
        final dg = cg - p.g;
        final db = cb - p.b;
        final dist = dr * dr + dg * dg + db * db;
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = p.index;
        }
      }
      grid[y][x] = closestIndex + 1;
    }
  }
  return grid;
}

String canvasToTextGrid(List<List<int>> grid) {
  final buffer = StringBuffer();
  final int height = grid.length;
  final int width = height > 0 ? grid[0].length : 0;
  if (height == 0 || width == 0) return '';

  // Header: 10s digits
  buffer.write('    ');
  for (int x = 0; x < width; x++) {
    buffer.write(x >= 10 ? '${x ~/ 10}' : ' ');
  }
  buffer.write('\n');

  // Header: 1s digits
  buffer.write('    ');
  for (int x = 0; x < width; x++) {
    buffer.write('${x % 10}');
  }
  buffer.write('\n');

  // Rows
  for (int y = 0; y < height; y++) {
    buffer.write('${y.toString().padLeft(3)} ');
    for (int x = 0; x < width; x++) {
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
  ui.Codec? codec;
  ui.Image? image;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return byteData.buffer.asUint8List();
    }
  } catch (e) {
    debugPrint('Error converting image to PNG: $e');
  } finally {
    image?.dispose();
    codec?.dispose();
  }
  return bytes;
}

/// Downscales a 2D color grid to a target size using nearest neighbor interpolation.
List<List<Color>> downscaleColorGrid(
  List<List<Color>> original,
  int targetSize,
) {
  if (original.isEmpty || original[0].isEmpty || targetSize <= 0) return [];
  final List<List<Color>> result = List.generate(
    targetSize,
    (_) => List.filled(targetSize, const Color(0xFF000000)),
  );
  final double scaleY = original.length / targetSize;
  final double scaleX = original[0].length / targetSize;
  for (int y = 0; y < targetSize; y++) {
    final int srcY = (y * scaleY).toInt().clamp(0, original.length - 1);
    for (int x = 0; x < targetSize; x++) {
      final int srcX = (x * scaleX).toInt().clamp(0, original[0].length - 1);
      result[y][x] = original[srcY][srcX];
    }
  }
  return result;
}
