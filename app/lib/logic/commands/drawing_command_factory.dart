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
import 'pixel_command.dart';
import 'pixels_command.dart';
import 'ellipse_command.dart';
import 'ellipse_filled_command.dart';
import 'triangle_command.dart';
import 'rotated_rectangle_command.dart';
import 'noise_rectangle_command.dart';
import 'noise_circle_command.dart';
import 'voronoi_command.dart';

typedef CommandCreator = DrawingCommand? Function(List<int> params);

/// Factory class to instantiate DrawingCommands from tool configurations.
class DrawingCommandFactory {
  static final Map<String, CommandCreator> _registry = {
    'line': (p) => p.length >= 4 ? LineCommand(p[0], p[1], p[2], p[3]) : null,
    'circle': (p) => p.length >= 3 ? CircleCommand(p[0], p[1], p[2]) : null,
    'circle_filled': (p) =>
        p.length >= 3 ? CircleFilledCommand(p[0], p[1], p[2]) : null,
    'circle_hatched': (p) =>
        p.length >= 3 ? CircleHatchedCommand(p[0], p[1], p[2]) : null,
    'rectangle': (p) =>
        p.length >= 4 ? RectangleCommand(p[0], p[1], p[2], p[3]) : null,
    'rectangle_filled': (p) =>
        p.length >= 4 ? RectangleFilledCommand(p[0], p[1], p[2], p[3]) : null,
    'rectangle_hatched': (p) =>
        p.length >= 4 ? RectangleHatchedCommand(p[0], p[1], p[2], p[3]) : null,
    'fill': (p) => p.length >= 2 ? FillCommand(p[0], p[1]) : null,
    'hatch': (p) => p.length >= 2 ? HatchCommand(p[0], p[1]) : null,
    'pixel': (p) => p.length >= 2 ? PixelCommand(p[0], p[1]) : null,
    'pixels': (p) => PixelsCommand(p),
    'ellipse': (p) =>
        p.length >= 4 ? EllipseCommand(p[0], p[1], p[2], p[3]) : null,
    'ellipse_filled': (p) =>
        p.length >= 4 ? EllipseFilledCommand(p[0], p[1], p[2], p[3]) : null,
    'triangle': (p) => p.length >= 6
        ? TriangleCommand(p[0], p[1], p[2], p[3], p[4], p[5])
        : null,
    'rotated_rectangle': (p) => p.length >= 5
        ? RotatedRectangleCommand(p[0], p[1], p[2], p[3], p[4].toDouble())
        : null,
    'noise_rectangle': (p) => p.length >= 5
        ? NoiseRectangleCommand(p[0], p[1], p[2], p[3], p[4])
        : null,
    'noise_circle': (p) =>
        p.length >= 4 ? NoiseCircleCommand(p[0], p[1], p[2], p[3]) : null,
    'voronoi': (p) => p.length >= 6
        ? VoronoiCommand(p[0], p[1], p[2], p[3], p[4], p[5])
        : null,
  };

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
    'pixel': PixelCommand.usage,
    'pixels': PixelsCommand.usage,
    'ellipse': EllipseCommand.usage,
    'ellipse_filled': EllipseFilledCommand.usage,
    'triangle': TriangleCommand.usage,
    'rotated_rectangle': RotatedRectangleCommand.usage,
    'noise_rectangle': NoiseRectangleCommand.usage,
    'noise_circle': NoiseCircleCommand.usage,
    'voronoi': VoronoiCommand.usage,
    'undo':
        'params [] (reverts the last AI or user action if the AI thinks the last stroke was a mistake)',
  };

  /// Allows dynamic registration of custom commands/tools.
  static void register(String toolName, CommandCreator creator, String usage) {
    _registry[toolName] = creator;
    toolInstructions[toolName] = usage;
  }

  /// Returns the matching [DrawingCommand] instance based on the [toolName] and [params].
  /// Returns `null` if the tool configurations are invalid or unsupported.
  static DrawingCommand? create(String toolName, List<int> params) {
    final creator = _registry[toolName];
    if (creator != null) {
      return creator(params);
    }
    return null;
  }
}
