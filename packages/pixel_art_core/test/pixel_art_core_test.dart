import 'dart:io';
import 'dart:typed_data';

import 'package:pixel_art_core/pixel_art_core.dart';

int _passed = 0;
int _failed = 0;

void _test(String name, void Function() fn) {
  try {
    fn();
    _passed++;
    stdout.writeln('  PASS: $name');
  } catch (e, st) {
    _failed++;
    stderr.writeln('  FAIL: $name\n    $e\n$st');
  }
}

void _expect(Object? actual, Object? expected, [String? reason]) {
  if (actual != expected) {
    throw AssertionError(
      '${reason != null ? '$reason: ' : ''}Expected <$expected> but got <$actual>',
    );
  }
}

void _expectTrue(bool cond, [String? reason]) {
  if (!cond) {
    throw AssertionError(reason ?? 'Expected condition to be true');
  }
}

void main() {
  stdout.writeln('Running pixel_art_core tests...');

  _test('PixelColor hex parsing and formatting', () {
    final c1 = PixelColor.parseHex('#ff8800');
    _expect(c1.r, 255);
    _expect(c1.g, 136);
    _expect(c1.b, 0);
    _expect(c1.a, 255);
    _expect(c1.toHex(), '#ff8800');

    final cShort = PixelColor.parseHex('#f80');
    _expect(cShort, c1);

    final cAlpha = PixelColor.parseHex('#80112233');
    _expect(cAlpha.a, 0x80);
    _expect(cAlpha.r, 0x11);
    _expect(cAlpha.g, 0x22);
    _expect(cAlpha.b, 0x33);
    _expect(PixelColor.tryParseHex('not-a-color'), null);
  });

  _test(
    'DrawingCommandFactory creates all commands including new icon ops',
    () {
      final grid = List.generate(16, (_) => List.filled(16, 0));

      DrawingCommandFactory.create('polygon', [
        2,
        2,
        7,
        2,
        7,
        7,
        2,
        7,
      ])!.execute(grid, 2, 16);
      _expect(grid[4][4], 2, 'Interior of polygon should be filled');
      _expect(grid[0][0], 0, 'Outside polygon should remain 0');

      DrawingCommandFactory.create('mirror_h', [])!.execute(grid, 0, 16);
      _expect(grid[4][11], 2, 'Mirrored pixel on right side');

      DrawingCommandFactory.create('replace_color', [2])!.execute(grid, 3, 16);
      _expect(grid[4][4], 3, 'Color 2 replaced with 3');
      _expect(grid[4][11], 3, 'Mirrored color 2 replaced with 3');

      DrawingCommandFactory.create('auto_outline', [4])!.execute(grid, 1, 16);
      _expect(grid[1][4], 1, 'Top outer outline pixel');
      _expect(grid[4][4], 3, 'Interior preserved by outer outline');
      _expect(grid[1][1], 0, '4-connected outline skips diagonal corner');
    },
  );

  _test('PixelArtComponent Bayer-dithered gradient and outline', () {
    final mask = List.generate(8, (_) => List.filled(8, 0));
    DrawingCommandFactory.create('rectangle_filled', [
      1,
      1,
      6,
      6,
    ])!.execute(mask, 1, 8);
    final comp = PixelArtComponent(
      name: 'box',
      description: 'shaded box',
      relativeBoundingBox: NormalizedRect.full,
      grid: mask,
      fillColor: PixelColor.parseHex('#ff0000'),
      fillColor2: PixelColor.parseHex('#0000ff'),
      gradientAngle: 90.0,
      outlineColor: PixelColor.black,
    );

    _expectTrue(comp.hasInterior, '6x6 box must have interior');
    _expect(comp.getPixelFillColor(3, 1), PixelColor.parseHex('#ff0000'));
    _expect(comp.getPixelFillColor(3, 6), PixelColor.parseHex('#0000ff'));
    _expect(comp.getOutlineGrid()![1][1], 1, 'Corner is outline');
    _expect(comp.getOutlineGrid()![3][3], 0, 'Center is not outline');
  });

  _test(
    'PixelArtScene renders named palette, mask dithering, rows, and postOps',
    () {
      final scene = PixelArtScene({
        'title': 'Test Gem',
        'gridSize': 16,
        'palette': {
          'ink': '#1a1c2c',
          'ruby': '#b13e53',
          'bright': '#ef7d57',
          'shine': '#f4f4f4',
        },
        'layers': [
          {
            'name': 'gem_body',
            'shapes': [
              {
                'tool': 'polygon',
                'params': [7, 2, 12, 7, 7, 13, 3, 7],
              },
            ],
            'fill': 'bright',
            'fill2': 'ruby',
            'gradientAngle': 135,
          },
          {
            'name': 'specular',
            'rows': ['..s', '.s.'],
            'offsetX': 4,
            'offsetY': 5,
            'legend': {'s': 'shine'},
          },
        ],
        'postOps': [
          {
            'tool': 'auto_outline',
            'params': [4],
            'color': 'ink',
          },
        ],
      });

      final res = scene.render();
      _expect(
        res.warnings.length,
        0,
        'Expected zero warnings: ${res.warnings}',
      );
      _expect(res.palette.length, 4);
      _expect(res.grid[5][6], 4, 'Specular highlight pixel placed via rows');
      _expect(res.grid[1][7], 1, 'Outer outline placed above top vertex');
      _expectTrue(res.filledPixelCount > 30, 'Gem should have >30 pixels');
    },
  );

  _test('PngEncoder produces valid PNG header, dimensions, and chunks', () {
    final grid = [
      [1, 2],
      [0, 1],
    ];
    final palette = [
      PixelColor.parseHex('#ff0000'),
      PixelColor.parseHex('#00ff00'),
    ];
    final bytes = PngEncoder.encodeGrid(grid, palette, scale: 4);

    // Check PNG signature
    _expect(
      bytes.sublist(0, 8).toList().toString(),
      '[137, 80, 78, 71, 13, 10, 26, 10]',
    );
    // Check IHDR width & height (2 * 4 = 8)
    final bd = ByteData.sublistView(bytes);
    _expect(bd.getUint32(16, Endian.big), 8, 'PNG width');
    _expect(bd.getUint32(20, Endian.big), 8, 'PNG height');
    _expect(bytes[24], 8, 'Bit depth 8');
    _expect(bytes[25], 6, 'Color type 6 (RGBA)');
  });

  _test('PreviewRenderer produces non-empty PNG and ASCII grid', () {
    final grid = SpriteTemplate.characterPreset.parseToGrid();
    final preview = PreviewRenderer.renderPreviewPng(
      grid,
      PaletteRegistry.sweetie16Palette.take(4).toList(),
      cellSize: 16,
    );
    _expectTrue(
      preview.length > 500,
      'Preview PNG should have meaningful size',
    );
    _expect(preview[0], 137);
    _expect(preview[1], 80);

    final ascii = PreviewRenderer.formatAsciiGrid(grid);
    _expectTrue(ascii.contains('1 1 1 1 1 1'), 'ASCII grid contains top row');
  });

  _test('SVG exporter merges contiguous horizontal runs', () {
    final grid = [
      [1, 1, 1, 0],
      [0, 2, 2, 0],
    ];
    final svg = generateSvgString(grid, [
      PixelColor.parseHex('#112233'),
      PixelColor.parseHex('#445566'),
    ], scale: 8);
    _expectTrue(svg.contains('width="32" height="16"'));
    _expectTrue(
      svg.contains('x="0" y="0" width="3" height="1" fill="#112233"'),
    );
    _expectTrue(
      svg.contains('x="1" y="1" width="2" height="1" fill="#445566"'),
    );
  });

  _test('kMeansQuantize extracts representative palette', () {
    final colorGrid = List.generate(
      4,
      (y) => List.generate(
        4,
        (x) => x < 2
            ? PixelColor.parseHex('#ff0000')
            : PixelColor.parseHex('#0000ff'),
      ),
    );
    final quantized = kMeansQuantize(colorGrid, 2);
    _expect(quantized.length, 2);
    _expectTrue(
      quantized.contains(PixelColor.parseHex('#ff0000')) &&
          quantized.contains(PixelColor.parseHex('#0000ff')),
    );
  });

  stdout.writeln('\nSummary: $_passed passed, $_failed failed.');
  if (_failed > 0) exit(1);
}
