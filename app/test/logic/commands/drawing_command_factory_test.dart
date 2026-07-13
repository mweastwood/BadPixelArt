import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/drawing_command_factory.dart';
import 'package:bad_pixel_art/logic/commands/line_command.dart';
import 'package:bad_pixel_art/logic/commands/circle_command.dart';
import 'package:bad_pixel_art/logic/commands/pixel_command.dart';
import 'package:bad_pixel_art/logic/commands/pixels_command.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_command.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_filled_command.dart';
import 'package:bad_pixel_art/logic/commands/triangle_command.dart';
import 'package:bad_pixel_art/logic/commands/rotated_rectangle_command.dart';
import 'package:bad_pixel_art/logic/commands/noise_rectangle_command.dart';
import 'package:bad_pixel_art/logic/commands/noise_circle_command.dart';
import 'package:bad_pixel_art/logic/commands/voronoi_command.dart';

void main() {
  group('DrawingCommandFactory Tests', () {
    test('instantiates correct commands', () {
      expect(
        DrawingCommandFactory.create('line', [0, 0, 3, 3]),
        isA<LineCommand>(),
      );
      expect(
        DrawingCommandFactory.create('circle', [2, 2, 2]),
        isA<CircleCommand>(),
      );
      expect(
        DrawingCommandFactory.create('pixel', [1, 2]),
        isA<PixelCommand>(),
      );
      expect(
        DrawingCommandFactory.create('pixels', [1, 2, 3, 4]),
        isA<PixelsCommand>(),
      );
      expect(
        DrawingCommandFactory.create('ellipse', [2, 2, 2, 1]),
        isA<EllipseCommand>(),
      );
      expect(
        DrawingCommandFactory.create('ellipse_filled', [2, 2, 2, 1]),
        isA<EllipseFilledCommand>(),
      );
      expect(
        DrawingCommandFactory.create('triangle', [0, 0, 1, 1, 2, 2]),
        isA<TriangleCommand>(),
      );
      expect(
        DrawingCommandFactory.create('rotated_rectangle', [2, 2, 4, 4, 45]),
        isA<RotatedRectangleCommand>(),
      );
      expect(
        DrawingCommandFactory.create('noise_rectangle', [0, 0, 3, 3, 42]),
        isA<NoiseRectangleCommand>(),
      );
      expect(
        DrawingCommandFactory.create('noise_circle', [2, 2, 2, 42]),
        isA<NoiseCircleCommand>(),
      );
      expect(
        DrawingCommandFactory.create('voronoi', [0, 0, 5, 5, 4, 42]),
        isA<VoronoiCommand>(),
      );
      expect(DrawingCommandFactory.create('invalid', [1, 2]), isNull);
    });
  });
}
