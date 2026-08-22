import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/base_command.dart';
import 'package:bad_pixel_art/logic/commands/drawing_command_factory.dart';
import 'package:bad_pixel_art/logic/commands/line_command.dart';
import 'package:bad_pixel_art/logic/commands/circle_command.dart';
import 'package:bad_pixel_art/logic/commands/circle_filled_command.dart';
import 'package:bad_pixel_art/logic/commands/circle_hatched_command.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_command.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_filled_command.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_hatched_command.dart';
import 'package:bad_pixel_art/logic/commands/fill_command.dart';
import 'package:bad_pixel_art/logic/commands/hatch_command.dart';
import 'package:bad_pixel_art/logic/commands/pixel_command.dart';
import 'package:bad_pixel_art/logic/commands/pixels_command.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_command.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_filled_command.dart';
import 'package:bad_pixel_art/logic/commands/triangle_command.dart';
import 'package:bad_pixel_art/logic/commands/rotated_rectangle_command.dart';
import 'package:bad_pixel_art/logic/commands/noise_rectangle_command.dart';
import 'package:bad_pixel_art/logic/commands/noise_circle_command.dart';
import 'package:bad_pixel_art/logic/commands/voronoi_command.dart';

class _CustomMockCommand implements DrawingCommand {
  final int x;
  final int y;

  _CustomMockCommand(this.x, this.y);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
      grid[y][x] = color;
    }
  }
}

void main() {
  group('DrawingCommandFactory Tests', () {
    group('Tool Registry Instantiation', () {
      test('instantiates LineCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('line', [0, 1, 2, 3]);
        expect(command, isA<LineCommand>());
        final line = command as LineCommand;
        expect(line.x1, equals(0));
        expect(line.y1, equals(1));
        expect(line.x2, equals(2));
        expect(line.y2, equals(3));
      });

      test('instantiates CircleCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('circle', [2, 3, 4]);
        expect(command, isA<CircleCommand>());
        final circle = command as CircleCommand;
        expect(circle.xc, equals(2));
        expect(circle.yc, equals(3));
        expect(circle.r, equals(4));
      });

      test('instantiates CircleFilledCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('circle_filled', [
          2,
          3,
          4,
        ]);
        expect(command, isA<CircleFilledCommand>());
        final circle = command as CircleFilledCommand;
        expect(circle.xc, equals(2));
        expect(circle.yc, equals(3));
        expect(circle.r, equals(4));
      });

      test('instantiates CircleHatchedCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('circle_hatched', [
          2,
          3,
          4,
        ]);
        expect(command, isA<CircleHatchedCommand>());
        final circle = command as CircleHatchedCommand;
        expect(circle.xc, equals(2));
        expect(circle.yc, equals(3));
        expect(circle.r, equals(4));
      });

      test('instantiates RectangleCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('rectangle', [0, 1, 2, 3]);
        expect(command, isA<RectangleCommand>());
        final rect = command as RectangleCommand;
        expect(rect.x1, equals(0));
        expect(rect.y1, equals(1));
        expect(rect.x2, equals(2));
        expect(rect.y2, equals(3));
      });

      test('instantiates RectangleFilledCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('rectangle_filled', [
          0,
          1,
          2,
          3,
        ]);
        expect(command, isA<RectangleFilledCommand>());
        final rect = command as RectangleFilledCommand;
        expect(rect.x1, equals(0));
        expect(rect.y1, equals(1));
        expect(rect.x2, equals(2));
        expect(rect.y2, equals(3));
      });

      test('instantiates RectangleHatchedCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('rectangle_hatched', [
          0,
          1,
          2,
          3,
        ]);
        expect(command, isA<RectangleHatchedCommand>());
        final rect = command as RectangleHatchedCommand;
        expect(rect.x1, equals(0));
        expect(rect.y1, equals(1));
        expect(rect.x2, equals(2));
        expect(rect.y2, equals(3));
      });

      test('instantiates FillCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('fill', [5, 6]);
        expect(command, isA<FillCommand>());
        final fill = command as FillCommand;
        expect(fill.startX, equals(5));
        expect(fill.startY, equals(6));
      });

      test('instantiates HatchCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('hatch', [5, 6]);
        expect(command, isA<HatchCommand>());
        final hatch = command as HatchCommand;
        expect(hatch.startX, equals(5));
        expect(hatch.startY, equals(6));
      });

      test('instantiates PixelCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('pixel', [1, 2]);
        expect(command, isA<PixelCommand>());
        final pixel = command as PixelCommand;
        expect(pixel.x, equals(1));
        expect(pixel.y, equals(2));
      });

      test('instantiates PixelsCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('pixels', [1, 2, 3, 4]);
        expect(command, isA<PixelsCommand>());
        final pixels = command as PixelsCommand;
        expect(pixels.coords, equals([1, 2, 3, 4]));
      });

      test('instantiates EllipseCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('ellipse', [2, 3, 4, 5]);
        expect(command, isA<EllipseCommand>());
        final ellipse = command as EllipseCommand;
        expect(ellipse.cx, equals(2));
        expect(ellipse.cy, equals(3));
        expect(ellipse.rx, equals(4));
        expect(ellipse.ry, equals(5));
      });

      test('instantiates EllipseFilledCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('ellipse_filled', [
          2,
          3,
          4,
          5,
        ]);
        expect(command, isA<EllipseFilledCommand>());
        final ellipse = command as EllipseFilledCommand;
        expect(ellipse.cx, equals(2));
        expect(ellipse.cy, equals(3));
        expect(ellipse.rx, equals(4));
        expect(ellipse.ry, equals(5));
      });

      test('instantiates TriangleCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('triangle', [
          0,
          1,
          2,
          3,
          4,
          5,
        ]);
        expect(command, isA<TriangleCommand>());
        final triangle = command as TriangleCommand;
        expect(triangle.x1, equals(0));
        expect(triangle.y1, equals(1));
        expect(triangle.x2, equals(2));
        expect(triangle.y2, equals(3));
        expect(triangle.x3, equals(4));
        expect(triangle.y3, equals(5));
      });

      test('instantiates RotatedRectangleCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('rotated_rectangle', [
          2,
          3,
          4,
          5,
          45,
        ]);
        expect(command, isA<RotatedRectangleCommand>());
        final rotRect = command as RotatedRectangleCommand;
        expect(rotRect.cx, equals(2));
        expect(rotRect.cy, equals(3));
        expect(rotRect.w, equals(4));
        expect(rotRect.h, equals(5));
        expect(rotRect.angle, equals(45.0));
      });

      test('instantiates NoiseRectangleCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('noise_rectangle', [
          0,
          1,
          2,
          3,
          42,
        ]);
        expect(command, isA<NoiseRectangleCommand>());
        final noiseRect = command as NoiseRectangleCommand;
        expect(noiseRect.x1, equals(0));
        expect(noiseRect.y1, equals(1));
        expect(noiseRect.x2, equals(2));
        expect(noiseRect.y2, equals(3));
        expect(noiseRect.seed, equals(42));
      });

      test('instantiates NoiseCircleCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('noise_circle', [
          2,
          3,
          4,
          42,
        ]);
        expect(command, isA<NoiseCircleCommand>());
        final noiseCircle = command as NoiseCircleCommand;
        expect(noiseCircle.cx, equals(2));
        expect(noiseCircle.cy, equals(3));
        expect(noiseCircle.r, equals(4));
        expect(noiseCircle.seed, equals(42));
      });

      test('instantiates VoronoiCommand with valid parameters', () {
        final command = DrawingCommandFactory.create('voronoi', [
          0,
          1,
          2,
          3,
          4,
          42,
        ]);
        expect(command, isA<VoronoiCommand>());
        final voronoi = command as VoronoiCommand;
        expect(voronoi.x1, equals(0));
        expect(voronoi.y1, equals(1));
        expect(voronoi.x2, equals(2));
        expect(voronoi.y2, equals(3));
        expect(voronoi.numCells, equals(4));
        expect(voronoi.seed, equals(42));
      });
    });

    group('Insufficient & Invalid Parameter Validation', () {
      test('returns null for line when fewer than 4 parameters', () {
        expect(DrawingCommandFactory.create('line', []), isNull);
        expect(DrawingCommandFactory.create('line', [0]), isNull);
        expect(DrawingCommandFactory.create('line', [0, 0]), isNull);
        expect(DrawingCommandFactory.create('line', [0, 0, 1]), isNull);
      });

      test('returns null for circle when fewer than 3 parameters', () {
        expect(DrawingCommandFactory.create('circle', []), isNull);
        expect(DrawingCommandFactory.create('circle', [0]), isNull);
        expect(DrawingCommandFactory.create('circle', [0, 0]), isNull);
      });

      test('returns null for circle_filled when fewer than 3 parameters', () {
        expect(DrawingCommandFactory.create('circle_filled', []), isNull);
        expect(DrawingCommandFactory.create('circle_filled', [0]), isNull);
        expect(DrawingCommandFactory.create('circle_filled', [0, 0]), isNull);
      });

      test('returns null for circle_hatched when fewer than 3 parameters', () {
        expect(DrawingCommandFactory.create('circle_hatched', []), isNull);
        expect(DrawingCommandFactory.create('circle_hatched', [0]), isNull);
        expect(DrawingCommandFactory.create('circle_hatched', [0, 0]), isNull);
      });

      test('returns null for rectangle when fewer than 4 parameters', () {
        expect(DrawingCommandFactory.create('rectangle', []), isNull);
        expect(DrawingCommandFactory.create('rectangle', [0]), isNull);
        expect(DrawingCommandFactory.create('rectangle', [0, 0]), isNull);
        expect(DrawingCommandFactory.create('rectangle', [0, 0, 1]), isNull);
      });

      test(
        'returns null for rectangle_filled when fewer than 4 parameters',
        () {
          expect(DrawingCommandFactory.create('rectangle_filled', []), isNull);
          expect(DrawingCommandFactory.create('rectangle_filled', [0]), isNull);
          expect(
            DrawingCommandFactory.create('rectangle_filled', [0, 0]),
            isNull,
          );
          expect(
            DrawingCommandFactory.create('rectangle_filled', [0, 0, 1]),
            isNull,
          );
        },
      );

      test(
        'returns null for rectangle_hatched when fewer than 4 parameters',
        () {
          expect(DrawingCommandFactory.create('rectangle_hatched', []), isNull);
          expect(
            DrawingCommandFactory.create('rectangle_hatched', [0]),
            isNull,
          );
          expect(
            DrawingCommandFactory.create('rectangle_hatched', [0, 0]),
            isNull,
          );
          expect(
            DrawingCommandFactory.create('rectangle_hatched', [0, 0, 1]),
            isNull,
          );
        },
      );

      test('returns null for ellipse when fewer than 4 parameters', () {
        expect(DrawingCommandFactory.create('ellipse', []), isNull);
        expect(DrawingCommandFactory.create('ellipse', [0]), isNull);
        expect(DrawingCommandFactory.create('ellipse', [0, 0]), isNull);
        expect(DrawingCommandFactory.create('ellipse', [0, 0, 1]), isNull);
      });

      test('returns null for ellipse_filled when fewer than 4 parameters', () {
        expect(DrawingCommandFactory.create('ellipse_filled', []), isNull);
        expect(DrawingCommandFactory.create('ellipse_filled', [0]), isNull);
        expect(DrawingCommandFactory.create('ellipse_filled', [0, 0]), isNull);
        expect(
          DrawingCommandFactory.create('ellipse_filled', [0, 0, 1]),
          isNull,
        );
      });

      test('returns null for fill when fewer than 2 parameters', () {
        expect(DrawingCommandFactory.create('fill', []), isNull);
        expect(DrawingCommandFactory.create('fill', [0]), isNull);
      });

      test('returns null for hatch when fewer than 2 parameters', () {
        expect(DrawingCommandFactory.create('hatch', []), isNull);
        expect(DrawingCommandFactory.create('hatch', [0]), isNull);
      });

      test('returns null for pixel when fewer than 2 parameters', () {
        expect(DrawingCommandFactory.create('pixel', []), isNull);
        expect(DrawingCommandFactory.create('pixel', [0]), isNull);
      });

      test('returns null for triangle when fewer than 6 parameters', () {
        expect(DrawingCommandFactory.create('triangle', []), isNull);
        expect(DrawingCommandFactory.create('triangle', [0]), isNull);
        expect(DrawingCommandFactory.create('triangle', [0, 0]), isNull);
        expect(DrawingCommandFactory.create('triangle', [0, 0, 1]), isNull);
        expect(DrawingCommandFactory.create('triangle', [0, 0, 1, 1]), isNull);
        expect(
          DrawingCommandFactory.create('triangle', [0, 0, 1, 1, 2]),
          isNull,
        );
      });

      test('returns null for voronoi when fewer than 6 parameters', () {
        expect(DrawingCommandFactory.create('voronoi', []), isNull);
        expect(DrawingCommandFactory.create('voronoi', [0]), isNull);
        expect(DrawingCommandFactory.create('voronoi', [0, 0]), isNull);
        expect(DrawingCommandFactory.create('voronoi', [0, 0, 1]), isNull);
        expect(DrawingCommandFactory.create('voronoi', [0, 0, 1, 1]), isNull);
        expect(
          DrawingCommandFactory.create('voronoi', [0, 0, 1, 1, 2]),
          isNull,
        );
      });

      test(
        'returns null for rotated_rectangle when fewer than 5 parameters',
        () {
          expect(DrawingCommandFactory.create('rotated_rectangle', []), isNull);
          expect(
            DrawingCommandFactory.create('rotated_rectangle', [0]),
            isNull,
          );
          expect(
            DrawingCommandFactory.create('rotated_rectangle', [0, 0]),
            isNull,
          );
          expect(
            DrawingCommandFactory.create('rotated_rectangle', [0, 0, 1]),
            isNull,
          );
          expect(
            DrawingCommandFactory.create('rotated_rectangle', [0, 0, 1, 1]),
            isNull,
          );
        },
      );

      test('returns null for noise_rectangle when fewer than 5 parameters', () {
        expect(DrawingCommandFactory.create('noise_rectangle', []), isNull);
        expect(DrawingCommandFactory.create('noise_rectangle', [0]), isNull);
        expect(DrawingCommandFactory.create('noise_rectangle', [0, 0]), isNull);
        expect(
          DrawingCommandFactory.create('noise_rectangle', [0, 0, 1]),
          isNull,
        );
        expect(
          DrawingCommandFactory.create('noise_rectangle', [0, 0, 1, 1]),
          isNull,
        );
      });

      test('returns null for noise_circle when fewer than 4 parameters', () {
        expect(DrawingCommandFactory.create('noise_circle', []), isNull);
        expect(DrawingCommandFactory.create('noise_circle', [0]), isNull);
        expect(DrawingCommandFactory.create('noise_circle', [0, 0]), isNull);
        expect(DrawingCommandFactory.create('noise_circle', [0, 0, 1]), isNull);
      });

      test('returns null for unknown or unsupported tool names', () {
        expect(DrawingCommandFactory.create('invalid', [1, 2]), isNull);
        expect(
          DrawingCommandFactory.create('unsupported_tool', [1, 2, 3]),
          isNull,
        );
        expect(DrawingCommandFactory.create('', [1, 2]), isNull);
      });
    });

    group('Tool Instructions Map', () {
      test('contains instructions for all built-in tools', () {
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('line', LineCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('circle', CircleCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('circle_filled', CircleFilledCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('circle_hatched', CircleHatchedCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('rectangle', RectangleCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('rectangle_filled', RectangleFilledCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('rectangle_hatched', RectangleHatchedCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('fill', FillCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('hatch', HatchCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('pixel', PixelCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('pixels', PixelsCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('ellipse', EllipseCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('ellipse_filled', EllipseFilledCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('triangle', TriangleCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('rotated_rectangle', RotatedRectangleCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('noise_rectangle', NoiseRectangleCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('noise_circle', NoiseCircleCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions,
          containsPair('voronoi', VoronoiCommand.usage),
        );
        expect(
          DrawingCommandFactory.toolInstructions.containsKey('undo'),
          isTrue,
        );
      });
    });

    group('Dynamic Tool Registration', () {
      test('successfully registers and creates custom tool', () {
        const customToolName = 'custom_mock_tool';
        const customUsage = 'params [x, y] (draws a custom mock pixel)';

        DrawingCommandFactory.register(
          customToolName,
          (p) => p.length >= 2 ? _CustomMockCommand(p[0], p[1]) : null,
          customUsage,
        );

        expect(
          DrawingCommandFactory.toolInstructions[customToolName],
          equals(customUsage),
        );

        final command = DrawingCommandFactory.create(customToolName, [10, 20]);
        expect(command, isA<_CustomMockCommand>());
        final mockCmd = command as _CustomMockCommand;
        expect(mockCmd.x, equals(10));
        expect(mockCmd.y, equals(20));

        expect(DrawingCommandFactory.create(customToolName, [10]), isNull);
      });
    });
  });
}
