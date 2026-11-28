import 'types.dart';

class PixelArtPalette {
  final String id;
  final String displayName;
  final List<PixelColor> colors;

  const PixelArtPalette({
    required this.id,
    required this.displayName,
    required this.colors,
  });
}

class PaletteRegistry {
  static const List<PixelColor> grayscalePalette = [
    PixelColor(0xFF000000), // Black
    PixelColor(0xFF555555), // Dark Gray
    PixelColor(0xFFAAAAAA), // Light Gray
    PixelColor(0xFFFFFFFF), // White
  ];

  static const List<PixelColor> primaryPalette = [
    PixelColor(0xFF000000), // Black
    PixelColor(0xFFFFFFFF), // White
    PixelColor(0xFFFF0000), // Red
    PixelColor(0xFF00FF00), // Green
    PixelColor(0xFF0000FF), // Blue
    PixelColor(0xFFFFFF00), // Yellow
    PixelColor(0xFFFF00FF), // Magenta
    PixelColor(0xFF00FFFF), // Cyan
  ];

  static const List<PixelColor> gameboyPalette = [
    PixelColor(0xFF0F380F),
    PixelColor(0xFF306230),
    PixelColor(0xFF8BAC0F),
    PixelColor(0xFF9BBC0F),
  ];

  static const List<PixelColor> nesPalette = [
    PixelColor(0xFF000000), // Black
    PixelColor(0xFFFCBCB0), // Peach/Skin
    PixelColor(0xFFF06800), // Red/Orange
    PixelColor(0xFFF8B800), // Yellow
    PixelColor(0xFF00A800), // Green
    PixelColor(0xFF0058F8), // Blue
    PixelColor(0xFFD800CC), // Purple
    PixelColor(0xFFFFFFFF), // White
  ];

  static const List<PixelColor> pico8Palette = [
    PixelColor(0xFF000000),
    PixelColor(0xFF1D2B53),
    PixelColor(0xFF7E2553),
    PixelColor(0xFF008751),
    PixelColor(0xFFAB5236),
    PixelColor(0xFF5F574F),
    PixelColor(0xFFC2C3C7),
    PixelColor(0xFFFFF1E8),
    PixelColor(0xFFFF004D),
    PixelColor(0xFFFFA300),
    PixelColor(0xFFFFEC27),
    PixelColor(0xFF00E436),
    PixelColor(0xFF29ADFF),
    PixelColor(0xFF83769C),
    PixelColor(0xFFFF77A8),
    PixelColor(0xFFFFCCAA),
  ];

  /// Sweetie 16 — a classic hue-shifted 16-color pixel art palette.
  static const List<PixelColor> sweetie16Palette = [
    PixelColor(0xFF1A1C2C), // 1: Deep Ink
    PixelColor(0xFF5D275D), // 2: Dark Purple
    PixelColor(0xFFB13E53), // 3: Crimson
    PixelColor(0xFFEF7D57), // 4: Orange
    PixelColor(0xFFFFCD75), // 5: Warm Yellow
    PixelColor(0xFFA7F070), // 6: Lime
    PixelColor(0xFF38B764), // 7: Green
    PixelColor(0xFF257179), // 8: Dark Teal
    PixelColor(0xFF29366F), // 9: Deep Blue
    PixelColor(0xFF3B5DC9), // 10: Royal Blue
    PixelColor(0xFF41A6F6), // 11: Sky Blue
    PixelColor(0xFF73EFF7), // 12: Cyan Highlight
    PixelColor(0xFFF4F4F4), // 13: Off-White
    PixelColor(0xFF94B0C2), // 14: Light Cool Gray
    PixelColor(0xFF566C86), // 15: Mid Slate
    PixelColor(0xFF333C57), // 16: Dark Slate
  ];

  static const List<PixelArtPalette> presets = [
    PixelArtPalette(
      id: 'grayscale',
      displayName: 'Grayscale',
      colors: grayscalePalette,
    ),
    PixelArtPalette(
      id: 'primary',
      displayName: 'Primary Colors',
      colors: primaryPalette,
    ),
    PixelArtPalette(
      id: 'gameboy',
      displayName: 'Gameboy',
      colors: gameboyPalette,
    ),
    PixelArtPalette(id: 'nes', displayName: 'NES', colors: nesPalette),
    PixelArtPalette(id: 'pico8', displayName: 'PICO-8', colors: pico8Palette),
    PixelArtPalette(
      id: 'sweetie16',
      displayName: 'Sweetie 16',
      colors: sweetie16Palette,
    ),
  ];

  static PixelArtPalette? findById(String id) {
    final normalized = id.trim().toLowerCase();
    for (final p in presets) {
      if (p.id == normalized) return p;
    }
    return null;
  }

  static PixelArtPalette getById(String id) {
    return findById(id) ?? presets[1]; // primary as default
  }
}
