/// Pure-Dart immutable 32-bit ARGB color representation.
class PixelColor {
  /// Packed 32-bit ARGB integer (`0xAARRGGBB`).
  final int value;

  const PixelColor(this.value);

  /// Creates a color from individual 0..255 channel values.
  const PixelColor.fromARGB(int a, int r, int g, int b)
    : value =
          ((a & 0xFF) << 24) |
          ((r & 0xFF) << 16) |
          ((g & 0xFF) << 8) |
          (b & 0xFF);

  /// Creates an opaque color from 0..255 RGB values.
  const PixelColor.fromRGB(int r, int g, int b)
    : value = 0xFF000000 | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);

  int get a => (value >> 24) & 0xFF;
  int get r => (value >> 16) & 0xFF;
  int get g => (value >> 8) & 0xFF;
  int get b => value & 0xFF;

  int toARGB32() => value;

  /// Formats as `#rrggbb` (or `#aarrggbb` when [includeAlpha] is true).
  String toHex({bool includeAlpha = false, bool uppercase = false}) {
    final hex = includeAlpha
        ? value.toRadixString(16).padLeft(8, '0')
        : (value & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${uppercase ? hex.toUpperCase() : hex}';
  }

  /// Parses `#RGB`, `#RGBA`, `#RRGGBB`, `#AARRGGBB`, or `0x...` hex strings.
  /// Returns `null` if invalid.
  static PixelColor? tryParseHex(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;

    final hasPrefix = s.startsWith('#') || s.toLowerCase().startsWith('0x');
    if (s.toLowerCase().startsWith('0x')) {
      s = s.substring(2).trim();
    } else if (s.startsWith('#')) {
      s = s.substring(1).trim();
    }

    if (hasPrefix && s.length == 3) {
      s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
    } else if (hasPrefix && s.length == 4) {
      // #RGBA -> AARRGGBB
      s = '${s[3]}${s[3]}${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
    }

    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) return null;

    if (s.length == 6) {
      final v = int.tryParse('FF$s', radix: 16);
      return v == null ? null : PixelColor(v);
    }
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      return v == null ? null : PixelColor(v);
    }
    return null;
  }

  /// Parses hex or throws [FormatException].
  factory PixelColor.parseHex(String hex) {
    final c = tryParseHex(hex);
    if (c == null) {
      throw FormatException('Invalid hex color: "$hex"');
    }
    return c;
  }

  static const PixelColor transparent = PixelColor(0x00000000);
  static const PixelColor black = PixelColor(0xFF000000);
  static const PixelColor white = PixelColor(0xFFFFFFFF);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PixelColor && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PixelColor(${toHex(includeAlpha: a != 255)})';
}

/// Pure-Dart normalized 2D rectangle (typically in `0.0..1.0` coordinates).
class NormalizedRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormalizedRect.fromLTWH(this.left, this.top, this.width, this.height);

  static const NormalizedRect zero = NormalizedRect.fromLTWH(0, 0, 0, 0);
  static const NormalizedRect full = NormalizedRect.fromLTWH(0, 0, 1, 1);

  double get right => left + width;
  double get bottom => top + height;

  Map<String, double> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory NormalizedRect.fromJson(Map<String, dynamic> json) {
    return NormalizedRect.fromLTWH(
      ((json['left'] as num?) ?? 0.0).toDouble(),
      ((json['top'] as num?) ?? 0.0).toDouble(),
      ((json['width'] as num?) ?? 1.0).toDouble(),
      ((json['height'] as num?) ?? 1.0).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedRect &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'NormalizedRect.fromLTWH($left, $top, $width, $height)';
}
