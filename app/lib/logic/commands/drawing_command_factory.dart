import 'base_command.dart';
import 'line_command.dart';
import 'circle_command.dart';
import 'circle_filled_command.dart';
import 'circle_hatched_command.dart';
import 'rectangle_command.dart';
import 'rectangle_filled_command.dart';
import 'rectangle_hatched_command.dart';
import 'fill_command.dart';
import 'hatch_command.dart';

/// Factory class to instantiate DrawingCommands from tool configurations.
class DrawingCommandFactory {
  /// Map of tool names to their respective instructions (arguments description).
  static final Map<String, String> toolInstructions = {
    'line': LineCommand.usage,
    'circle': CircleCommand.usage,
    'circle_filled': CircleFilledCommand.usage,
    'circle_hatched': CircleHatchedCommand.usage,
    'rectangle': RectangleCommand.usage,
    'rectangle_filled': RectangleFilledCommand.usage,
    'rectangle_hatched': RectangleHatchedCommand.usage,
    'fill': FillCommand.usage,
    'hatch': HatchCommand.usage,
    'undo':
        'params [] (reverts the last AI or user action if the AI thinks the last stroke was a mistake)',
  };

  /// Returns the matching [DrawingCommand] instance based on the [toolName] and [params].
  /// Returns `null` if the tool configurations are invalid or unsupported.
  static DrawingCommand? create(String toolName, List<int> params) {
    switch (toolName) {
      case 'line':
        if (params.length >= 4) {
          return LineCommand(params[0], params[1], params[2], params[3]);
        }
        break;
      case 'circle':
        if (params.length >= 3) {
          return CircleCommand(params[0], params[1], params[2]);
        }
        break;
      case 'circle_filled':
        if (params.length >= 3) {
          return CircleFilledCommand(params[0], params[1], params[2]);
        }
        break;
      case 'circle_hatched':
        if (params.length >= 3) {
          return CircleHatchedCommand(params[0], params[1], params[2]);
        }
        break;
      case 'rectangle':
        if (params.length >= 4) {
          return RectangleCommand(params[0], params[1], params[2], params[3]);
        }
        break;
      case 'rectangle_filled':
        if (params.length >= 4) {
          return RectangleFilledCommand(
            params[0],
            params[1],
            params[2],
            params[3],
          );
        }
        break;
      case 'rectangle_hatched':
        if (params.length >= 4) {
          return RectangleHatchedCommand(
            params[0],
            params[1],
            params[2],
            params[3],
          );
        }
        break;
      case 'fill':
        if (params.length >= 2) {
          return FillCommand(params[0], params[1]);
        }
        break;
      case 'hatch':
        if (params.length >= 2) {
          return HatchCommand(params[0], params[1]);
        }
        break;
    }
    return null;
  }
}
