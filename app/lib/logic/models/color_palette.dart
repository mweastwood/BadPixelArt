import 'package:flutter/material.dart';

class PixelArtPalette {
  final String id;
  final String displayName;
  final List<Color> colors;

  const PixelArtPalette({
    required this.id,
    required this.displayName,
    required this.colors,
  });
}

class PaletteRegistry {
  static const List<Color> grayscalePalette = [
    Color(0xFF000000), // Black
    Color(0xFF555555), // Dark Gray
    Color(0xFFAAAAAA), // Light Gray
    Color(0xFFFFFFFF), // White
  ];

  static const List<Color> primaryPalette = [
    Color(0xFF000000), // Black
    Color(0xFFFFFFFF), // White
    Color(0xFFFF0000), // Red
    Color(0xFF00FF00), // Green
    Color(0xFF0000FF), // Blue
    Color(0xFFFFFF00), // Yellow
    Color(0xFFFF00FF), // Magenta
    Color(0xFF00FFFF), // Cyan
  ];

  static const List<Color> gameboyPalette = [
    Color(0xFF0F380F),
    Color(0xFF306230),
    Color(0xFF8BAC0F),
    Color(0xFF9BBC0F),
  ];

  static const List<Color> nesPalette = [
    Color(0xFF000000), // Black
    Color(0xFFFCBCB0), // Peach/Skin
    Color(0xFFF06800), // Red/Orange
    Color(0xFFF8B800), // Yellow
    Color(0xFF00A800), // Green
    Color(0xFF0058F8), // Blue
    Color(0xFFD800CC), // Purple
    Color(0xFFFFFFFF), // White
  ];

  static const List<Color> pico8Palette = [
    Color(0xFF000000),
    Color(0xFF1D2B53),
    Color(0xFF7E2553),
    Color(0xFF008751),
    Color(0xFFAB5236),
    Color(0xFF5F574F),
    Color(0xFFC2C3C7),
    Color(0xFFFFF1E8),
    Color(0xFFFF004D),
    Color(0xFFFFA300),
    Color(0xFFFFEC27),
    Color(0xFF00E436),
    Color(0xFF29ADFF),
    Color(0xFF83769C),
    Color(0xFFFF77A8),
    Color(0xFFFFCCAA),
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
  ];

  static PixelArtPalette getById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets[1], // primary as default
    );
  }
}
