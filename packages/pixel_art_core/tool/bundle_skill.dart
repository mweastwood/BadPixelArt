import 'dart:io';

/// Bundles `packages/pixel_art_core` and `bin/pixel_art.dart` into a single
/// standalone, zero-dependency Dart file at `../../skills/bad-pixel-art/scripts/pixel_art.dart`.
void main() {
  final sourceFiles = <String>[
    'lib/src/types.dart',
    'lib/src/utils/noise_utils.dart',
    'lib/src/coordinate_converter.dart',
    'lib/src/bounded_canvas.dart',
    'lib/src/commands/base_command.dart',
    'lib/src/commands/line_command.dart',
    'lib/src/commands/circle_command.dart',
    'lib/src/commands/circle_filled_command.dart',
    'lib/src/commands/circle_hatched_command.dart',
    'lib/src/commands/rectangle_command.dart',
    'lib/src/commands/rectangle_filled_command.dart',
    'lib/src/commands/rectangle_hatched_command.dart',
    'lib/src/commands/fill_command.dart',
    'lib/src/commands/hatch_command.dart',
    'lib/src/commands/pixel_command.dart',
    'lib/src/commands/pixels_command.dart',
    'lib/src/commands/ellipse_command.dart',
    'lib/src/commands/ellipse_filled_command.dart',
    'lib/src/commands/triangle_command.dart',
    'lib/src/commands/rotated_rectangle_command.dart',
    'lib/src/commands/noise_rectangle_command.dart',
    'lib/src/commands/noise_circle_command.dart',
    'lib/src/commands/voronoi_command.dart',
    'lib/src/commands/polygon_command.dart',
    'lib/src/commands/mirror_command.dart',
    'lib/src/commands/replace_color_command.dart',
    'lib/src/commands/outline_command.dart',
    'lib/src/commands/drawing_command_factory.dart',
    'lib/src/palettes.dart',
    'lib/src/k_means_quantizer.dart',
    'lib/src/component.dart',
    'lib/src/sprite_template.dart',
    'lib/src/png_encoder.dart',
    'lib/src/svg_exporter.dart',
    'lib/src/preview_renderer.dart',
    'lib/src/scene.dart',
    'bin/pixel_art.dart',
  ];

  final out = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT DIRECTLY.')
    ..writeln(
      '// Regenerate via: cd packages/pixel_art_core && dart run tool/bundle_skill.dart',
    )
    ..writeln('// ignore_for_file: unused_element, unused_local_variable')
    ..writeln()
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:io';")
    ..writeln("import 'dart:math';")
    ..writeln("import 'dart:math' as math;")
    ..writeln("import 'dart:typed_data';")
    ..writeln();

  final importLine = RegExp(
    r"^\s*(import|export|library)\s+['"
    r'"'
    r"].*;\s*$",
  );

  for (final path in sourceFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('Missing source file: $path');
      exit(1);
    }
    out.writeln('// === $path ===');
    for (final line in file.readAsLinesSync()) {
      if (importLine.hasMatch(line)) continue;
      out.writeln(line);
    }
    out.writeln();
  }

  final target = File('../../skills/bad-pixel-art/scripts/pixel_art.dart');
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(out.toString());
  stdout.writeln(
    'Bundled ${sourceFiles.length} files -> ${target.path} (${target.lengthSync()} bytes)',
  );
}
