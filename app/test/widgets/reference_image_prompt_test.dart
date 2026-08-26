import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';

import '../test_helper.dart';

void main() {
  group('ReferenceImagePrompt Widget & Golden Tests', () {
    testWidgets(
      'renders initial expanded state correctly with upload and library options',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        // Verify the header title
        expect(find.text('Reference & Prompt'), findsOneWidget);
        expect(find.text('Reference Image'), findsOneWidget);
        expect(find.text('Upload Image'), findsOneWidget);
        expect(find.text('From Library'), findsOneWidget);
        expect(find.text('User Instructions / Prompt'), findsOneWidget);
      },
    );

    testWidgets('tapping From Library opens picker', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(body: ReferenceImagePrompt()),
        ),
      );

      final fromLibraryButton = find.byKey(
        const ValueKey('library_reference_button'),
      );
      expect(fromLibraryButton, findsOneWidget);
      await tester.tap(fromLibraryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Select Reference Image'), findsOneWidget);
    });

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
