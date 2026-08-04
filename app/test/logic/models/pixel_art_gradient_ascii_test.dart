import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

void main() {
  group('Pixel Art Hatching Gradient ASCII Rendering Tests', () {
    const colorA = Color(0xFF111111);
    const colorB = Color(0xFFFFFFFF);

    String renderAsciiGradient(PixelArtComponent comp) {
      final grid = comp.grid!;
      final size = grid.length;
      final lines = <String>[];

      for (int y = 0; y < size; y++) {
        final row = StringBuffer();
        for (int x = 0; x < size; x++) {
          if (grid[y][x] == 0) {
            row.write('.');
          } else {
            final col = comp.getPixelFillColor(x, y);
            if (col?.toARGB32() == colorA.toARGB32()) {
              row.write('A');
            } else if (col?.toARGB32() == colorB.toARGB32()) {
              row.write('B');
            } else {
              row.write('?');
            }
          }
        }
        lines.add(row.toString());
      }
      return lines.join('\n');
    }

    test('0° Angle (Horizontal Left-to-Right Hatching Gradient)', () {
      final solid8x8 = List.generate(8, (y) => List.generate(8, (x) => 1));
      final comp = PixelArtComponent(
        name: 'square',
        description: 'square',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        grid: solid8x8,
        fillColor: colorA,
        fillColor2: colorB,
        gradientAngle: 0.0, // Left to Right
      );

      final ascii = renderAsciiGradient(comp);
      expect(
        ascii,
        equals(
          'AABABBBB\n'
          'AAABABAB\n'
          'AABABBBB\n'
          'AAABABBB\n'
          'AABABBBB\n'
          'AAABABAB\n'
          'AABABBBB\n'
          'AAABABBB',
        ),
      );
    });

    test('90° Angle (Vertical Top-to-Bottom Hatching Gradient)', () {
      final solid8x8 = List.generate(8, (y) => List.generate(8, (x) => 1));
      final comp = PixelArtComponent(
        name: 'square',
        description: 'square',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        grid: solid8x8,
        fillColor: colorA,
        fillColor2: colorB,
        gradientAngle: 90.0, // Top to Bottom
      );

      final ascii = renderAsciiGradient(comp);
      expect(
        ascii,
        equals(
          'AAAABAAA\n'
          'AAAAAAAA\n'
          'BABABABA\n'
          'AAABAAAB\n'
          'BBBABBBA\n'
          'ABABABAB\n'
          'BBBBBBBB\n'
          'BBBBBBBB',
        ),
      );
    });

    test('45° Angle (Diagonal Top-Left to Bottom-Right Hatching Gradient)', () {
      final solid8x8 = List.generate(8, (y) => List.generate(8, (x) => 1));
      final comp = PixelArtComponent(
        name: 'square',
        description: 'square',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        grid: solid8x8,
        fillColor: colorA,
        fillColor2: colorB,
        gradientAngle: 45.0, // Diagonal Top-Left to Bottom-Right
      );

      final ascii = renderAsciiGradient(comp);
      expect(
        ascii,
        equals(
          'AABABABA\n'
          'AAAAABAB\n'
          'AABABABB\n'
          'AAABABAB\n'
          'BABABBBB\n'
          'ABABABAB\n'
          'BABBBBBB\n'
          'ABABABBB',
        ),
      );
    });

    test(
      '135° Angle (Diagonal Top-Right to Bottom-Left Hatching Gradient)',
      () {
        final solid8x8 = List.generate(8, (y) => List.generate(8, (x) => 1));
        final comp = PixelArtComponent(
          name: 'square',
          description: 'square',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: solid8x8,
          fillColor: colorA,
          fillColor2: colorB,
          gradientAngle: 135.0, // Diagonal Top-Right to Bottom-Left
        );

        final ascii = renderAsciiGradient(comp);
        expect(
          ascii,
          equals(
            'BABABAAA\n'
            'ABAAAAAA\n'
            'BABABABA\n'
            'ABABAAAA\n'
            'BBBABABA\n'
            'BBABABAA\n'
            'BBBBBABA\n'
            'BBBBABAB',
          ),
        );
      },
    );

    test('180° Angle (Horizontal Right-to-Left Hatching Gradient)', () {
      final solid8x8 = List.generate(8, (y) => List.generate(8, (x) => 1));
      final comp = PixelArtComponent(
        name: 'square',
        description: 'square',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        grid: solid8x8,
        fillColor: colorA,
        fillColor2: colorB,
        gradientAngle: 180.0, // Right to Left
      );

      final ascii = renderAsciiGradient(comp);
      expect(
        ascii,
        equals(
          'BBBABABA\n'
          'BBABABAA\n'
          'BBBBBABA\n'
          'BBABAAAA\n'
          'BBBABABA\n'
          'BBABABAA\n'
          'BBBBBABA\n'
          'BBABAAAA',
        ),
      );
    });

    test('270° Angle (Vertical Bottom-to-Top Hatching Gradient)', () {
      final solid8x8 = List.generate(8, (y) => List.generate(8, (x) => 1));
      final comp = PixelArtComponent(
        name: 'square',
        description: 'square',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        grid: solid8x8,
        fillColor: colorA,
        fillColor2: colorB,
        gradientAngle: 270.0, // Bottom to Top
      );

      final ascii = renderAsciiGradient(comp);
      expect(
        ascii,
        equals(
          'BBBBBBBB\n'
          'BBABBBAB\n'
          'BBBBBBBB\n'
          'ABABABAB\n'
          'BABABABA\n'
          'ABAAABAA\n'
          'AABAAABA\n'
          'AAAAAAAA',
        ),
      );
    });

    test(
      'Hollow / Non-Interior Component Fallback to Single Color (Color A)',
      () {
        final hollowGrid = List.generate(
          8,
          (y) => List.generate(8, (x) {
            if (x == 0 || x == 7 || y == 0 || y == 7) return 1;
            return 0;
          }),
        );

        final comp = PixelArtComponent(
          name: 'hollow_box',
          description: 'hollow box',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: hollowGrid,
          fillColor: colorA,
          fillColor2: colorB,
          gradientAngle: 45.0,
        );

        expect(comp.hasInterior, isFalse);

        final ascii = renderAsciiGradient(comp);
        expect(
          ascii,
          equals(
            'AAAAAAAA\n'
            'A......A\n'
            'A......A\n'
            'A......A\n'
            'A......A\n'
            'A......A\n'
            'A......A\n'
            'AAAAAAAA',
          ),
        );
      },
    );
  });
}
