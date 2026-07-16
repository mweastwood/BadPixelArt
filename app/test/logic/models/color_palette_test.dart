import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/color_palette.dart';

void main() {
  group('Color Palette Model and Registry Tests', () {
    test('PixelArtPalette properties are set correctly', () {
      final colors = [Colors.red, Colors.green];
      final palette = PixelArtPalette(
        id: 'test_id',
        displayName: 'Test Palette',
        colors: colors,
      );

      expect(palette.id, equals('test_id'));
      expect(palette.displayName, equals('Test Palette'));
      expect(palette.colors, equals(colors));
    });

    test('PaletteRegistry contains expected preset palettes', () {
      final presets = PaletteRegistry.presets;
      expect(presets, isNotEmpty);

      // Verify grayscale exists
      final grayscale = presets.firstWhere((p) => p.id == 'grayscale');
      expect(grayscale.displayName, equals('Grayscale'));
      expect(grayscale.colors, equals(PaletteRegistry.grayscalePalette));

      // Verify primary exists
      final primary = presets.firstWhere((p) => p.id == 'primary');
      expect(primary.displayName, equals('Primary Colors'));
      expect(primary.colors, equals(PaletteRegistry.primaryPalette));
    });

    test('PaletteRegistry.getById returns correct palette or default', () {
      // Get NES palette
      final nes = PaletteRegistry.getById('nes');
      expect(nes.id, equals('nes'));
      expect(nes.displayName, equals('NES'));
      expect(nes.colors, equals(PaletteRegistry.nesPalette));

      // Get unknown ID returns default (primary)
      final unknown = PaletteRegistry.getById('unknown_id');
      expect(unknown.id, equals('primary'));
    });
  });
}
