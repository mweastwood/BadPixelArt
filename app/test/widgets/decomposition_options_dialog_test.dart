import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/decomposition_options_dialog.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

void main() {
  group('DecompositionOptionsDialog Widget & Golden Tests', () {
    testGoldens('DecompositionOptionsDialog renders correctly', (tester) async {
      final option = [
        PixelArtComponent(
          name: 'blade',
          description: 'vertical blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
        ),
      ];

      await tester.pumpWidgetBuilder(
        DecompositionOptionsDialog(
          options: [option, option, option, option],
          onSelected: (_) {},
          onCancel: () {},
        ),
        wrapper: testMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'decomposition_options_dialog');
    });
  });
}
