import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import '../test_helper.dart';

void main() {
  group('ReferenceImagePrompt Widget & Golden Tests', () {
    testWidgets(
      'renders initial expanded state correctly when no reference image',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        // Verify the header title
        expect(find.text('Reference & Prompt'), findsOneWidget);
        expect(find.text('Reference Image'), findsOneWidget);
        expect(find.text('Upload Reference Image'), findsOneWidget);
        expect(find.text('User Instructions / Prompt'), findsOneWidget);
      },
    );

    testGoldens('ReferenceImagePrompt renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario('Empty State', const ReferenceImagePrompt());

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'reference_image_prompt');
    });
  });
}
