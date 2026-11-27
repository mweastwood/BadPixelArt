import 'dart:io';
import 'dart:typed_data';

import 'types.dart';

/// Pure-Dart RGBA PNG encoder using `dart:io`'s built-in [ZLibEncoder].
class PngEncoder {
  static final Uint32List _crcTable = _buildCrcTable();

  static Uint32List _buildCrcTable() {
    final table = Uint32List(256);
    for (int n = 0; n < 256; n++) {
      int c = n;
      for (int k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[n] = c;
    }
    return table;
  }

  static int _crc32(List<int> bytes) {
    int c = 0xFFFFFFFF;
    for (int i = 0; i < bytes.length; i++) {
      c = _crcTable[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List _chunk(String type, List<int> data) {
    assert(type.length == 4);
    final typeBytes = type.codeUnits;
    final out = Uint8List(12 + data.length);
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, data.length, Endian.big);
    for (int i = 0; i < 4; i++) {
      out[4 + i] = typeBytes[i];
    }
    out.setRange(8, 8 + data.length, data);
    final crcInput = Uint8List.sublistView(out, 4, 8 + data.length);
    bd.setUint32(8 + data.length, _crc32(crcInput), Endian.big);
    return out;
  }

  /// Encodes a flat RGBA byte buffer ([rgba], length `width * height * 4`)
  /// into a valid lossless 8-bit RGBA PNG byte array.
  static Uint8List encodeRgba(int width, int height, Uint8List rgba) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('PNG dimensions must be positive: ${width}x$height');
    }
    if (rgba.length != width * height * 4) {
      throw ArgumentError(
        'RGBA buffer length (${rgba.length}) does not match '
        '${width}x$height*4 (${width * height * 4})',
      );
    }

    // PNG signature
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];

    // IHDR chunk: width, height, bit depth 8, color type 6 (RGBA),
    // compression 0, filter 0, interlace 0
    final ihdrData = Uint8List(13);
    final ihdrBd = ByteData.sublistView(ihdrData);
    ihdrBd.setUint32(0, width, Endian.big);
    ihdrBd.setUint32(4, height, Endian.big);
    ihdrData[8] = 8; // bit depth
    ihdrData[9] = 6; // RGBA
    ihdrData[10] = 0; // deflate
    ihdrData[11] = 0; // adaptive filter
    ihdrData[12] = 0; // no interlace

    // Prepare raw scanlines with filter byte 0 (None) before each row
    final rowBytes = width * 4;
    final raw = Uint8List(height * (1 + rowBytes));
    for (int y = 0; y < height; y++) {
      final dstOffset = y * (1 + rowBytes);
      raw[dstOffset] = 0; // filter type 0
      final srcOffset = y * rowBytes;
      raw.setRange(dstOffset + 1, dstOffset + 1 + rowBytes, rgba, srcOffset);
    }

    final compressed = zlib.encode(raw);

    final ihdr = _chunk('IHDR', ihdrData);
    final idat = _chunk('IDAT', compressed);
    final iend = _chunk('IEND', const []);

    final builder = BytesBuilder(copy: false)
      ..add(signature)
      ..add(ihdr)
      ..add(idat)
      ..add(iend);
    return builder.toBytes();
  }

  /// Encodes a palette-indexed pixel art [grid] and [palette] into a crisp
  /// nearest-neighbor scaled RGBA PNG.
  static Uint8List encodeGrid(
    List<List<int>> grid,
    List<PixelColor> palette, {
    int scale = 1,
    bool transparentBackground = true,
    PixelColor backgroundColor = const PixelColor(0xFF1E1E1E),
  }) {
    final int height = grid.length;
    final int width = height > 0 ? grid[0].length : 0;
    if (width <= 0 || height <= 0 || scale <= 0) {
      return Uint8List(0);
    }

    final int outWidth = width * scale;
    final int outHeight = height * scale;
    final rgba = Uint8List(outWidth * outHeight * 4);

    final bgA = transparentBackground ? 0 : backgroundColor.a;
    final bgR = transparentBackground ? 0 : backgroundColor.r;
    final bgG = transparentBackground ? 0 : backgroundColor.g;
    final bgB = transparentBackground ? 0 : backgroundColor.b;

    for (int y = 0; y < height; y++) {
      final row = grid[y];
      for (int x = 0; x < width; x++) {
        final idx = x < row.length ? row[x] : 0;
        int r = bgR, g = bgG, b = bgB, a = bgA;
        if (idx > 0 && idx <= palette.length) {
          final c = palette[idx - 1];
          r = c.r;
          g = c.g;
          b = c.b;
          a = c.a;
        }

        final pyStart = y * scale;
        final pxStart = x * scale;
        for (int sy = 0; sy < scale; sy++) {
          final rowBase = ((pyStart + sy) * outWidth + pxStart) * 4;
          for (int sx = 0; sx < scale; sx++) {
            final off = rowBase + sx * 4;
            rgba[off] = r;
            rgba[off + 1] = g;
            rgba[off + 2] = b;
            rgba[off + 3] = a;
          }
        }
      }
    }

    return encodeRgba(outWidth, outHeight, rgba);
  }
}
