import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/drawing_command_factory.dart';
import 'package:bad_pixel_art/logic/commands/line_command.dart';
import 'package:bad_pixel_art/logic/commands/circle_command.dart';

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
      expect(DrawingCommandFactory.create('invalid', [1, 2]), isNull);
    });
  });
}
