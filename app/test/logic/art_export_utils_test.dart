import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/utils/art_export_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('art_export_utils tests', () {
    test('sanitizeFileName removes invalid characters and whitespace', () {
      expect(sanitizeFileName('My Cool Pixel Art!'), 'My_Cool_Pixel_Art!');
      expect(
        sanitizeFileName(
          'Art / Slash \\ Backslash : Colons * Star ? Query " Quote < Less > Greater | Pipe',
        ),
        'Art_Slash_Backslash_Colons_Star_Query_Quote_Less_Greater_Pipe',
      );
      expect(sanitizeFileName('   '), startsWith('pixel_art_'));
      expect(sanitizeFileName('___'), startsWith('pixel_art_'));
      expect(sanitizeFileName('spaceship'), 'spaceship');
    });

    test('colorToHex formats color as uppercase 6-char hex', () {
      expect(colorToHex(const Color(0xFFFF0000)), '#ff0000');
      expect(colorToHex(const Color(0xFF00FF00)), '#00ff00');
      expect(colorToHex(const Color(0xFF0000FF)), '#0000ff');
      expect(colorToHex(const Color(0xFFFFFFFF)), '#ffffff');
      expect(colorToHex(const Color(0xFF1E1E1E)), '#1e1e1e');
    });

    test(
      'generatePngBytes returns empty bytes for empty grid or scale <= 0',
      () async {
        final bytes1 = await generatePngBytes([], [Colors.red]);
        expect(bytes1, isEmpty);

        final bytes2 = await generatePngBytes(
          [
            [1],
          ],
          [Colors.red],
          scale: 0,
        );
        expect(bytes2, isEmpty);
      },
    );

    test('generatePngBytes produces valid PNG with header bytes', () async {
      final grid = [
        [1, 0],
        [0, 2],
      ];
      final palette = [const Color(0xFFFF0000), const Color(0xFF0000FF)];

      final pngBytes = await generatePngBytes(
        grid,
        palette,
        scale: 4,
        transparentBackground: true,
      );
      expect(pngBytes, isNotEmpty);
      // Check PNG magic bytes: 137 80 78 71 13 10 26 10
      expect(
        pngBytes.sublist(0, 8),
        equals(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
      );
    });

    test('generatePngBytes works with solid background', () async {
      final grid = [
        [0, 1],
        [1, 0],
      ];
      final palette = [const Color(0xFFFF0000)];

      final pngBytes = await generatePngBytes(
        grid,
        palette,
        scale: 1,
        transparentBackground: false,
        backgroundColor: const Color(0xFF000000),
      );
      expect(pngBytes, isNotEmpty);
      expect(
        pngBytes.sublist(0, 8),
        equals(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
      );
    });

    test('generateSvgString returns fallback for empty grid or scale <= 0', () {
      final svg1 = generateSvgString([], [Colors.red]);
      expect(svg1, contains('<svg'));
      expect(svg1, contains('viewBox="0 0 1 1"'));

      final svg2 = generateSvgString(
        [
          [1],
        ],
        [Colors.red],
        scale: -1,
      );
      expect(svg2, contains('viewBox="0 0 1 1"'));
    });

    test(
      'generateSvgString generates valid SVG with dimensions and optimized horizontal runs',
      () {
        final grid = [
          [1, 1, 1, 0],
          [0, 2, 2, 1],
        ];
        final palette = [const Color(0xFFFF0000), const Color(0xFF00FF00)];

        final svg = generateSvgString(
          grid,
          palette,
          scale: 8,
          transparentBackground: true,
        );

        expect(
          svg,
          contains(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4 2" width="32" height="16" shape-rendering="crispEdges">',
          ),
        );
        // Run length of 3 red pixels on row 0
        expect(
          svg,
          contains('<rect x="0" y="0" width="3" height="1" fill="#ff0000" />'),
        );
        // Run length of 2 green pixels on row 1
        expect(
          svg,
          contains('<rect x="1" y="1" width="2" height="1" fill="#00ff00" />'),
        );
        // Single red pixel at x=3, y=1
        expect(
          svg,
          contains('<rect x="3" y="1" width="1" height="1" fill="#ff0000" />'),
        );
        // Should NOT contain background rect because transparentBackground is true
        expect(svg, isNot(contains('<rect width="100%" height="100%"')));
        expect(svg.trim(), endsWith('</svg>'));
      },
    );

    test(
      'generateSvgString includes background rect when transparentBackground is false',
      () {
        final grid = [
          [1, 0],
          [0, 1],
        ];
        final palette = [const Color(0xFFFF0000)];

        final svg = generateSvgString(
          grid,
          palette,
          scale: 4,
          transparentBackground: false,
          backgroundColor: const Color(0xFF1E1E1E),
        );

        expect(
          svg,
          contains('<rect width="100%" height="100%" fill="#1e1e1e" />'),
        );
        expect(
          svg,
          contains('<rect x="0" y="0" width="1" height="1" fill="#ff0000" />'),
        );
        expect(
          svg,
          contains('<rect x="1" y="1" width="1" height="1" fill="#ff0000" />'),
        );
      },
    );
  });
}
