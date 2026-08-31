import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/wizard/wizard_step_definition.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helper.dart';

class _TestWizardStepDefinition extends WizardStepDefinition {
  const _TestWizardStepDefinition({this.customDescription});

  final String? customDescription;

  @override
  WizardStep get step => WizardStep.selectGridSize;

  @override
  String get title => 'Test Step Title';

  @override
  String? get description => customDescription ?? super.description;

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) {
    return const KeyedSubtree(
      key: Key('test_wizard_step_widget'),
      child: SizedBox(),
    );
  }
}

void main() {
  group('WizardStepDefinition Tests', () {
    test('default description getter returns null', () {
      const step = _TestWizardStepDefinition();
      expect(step.description, isNull);
      expect(step.step, equals(WizardStep.selectGridSize));
      expect(step.title, equals('Test Step Title'));
    });

    test('overridden description returns custom string', () {
      const step = _TestWizardStepDefinition(
        customDescription: 'Custom Description',
      );
      expect(step.description, equals('Custom Description'));
    });

    testWidgets(
      'default canAdvance, canGoBack, and onManualAdvance operate properly with WidgetRef',
      (tester) async {
        const step = _TestWizardStepDefinition();
        WidgetRef? capturedRef;

        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                capturedRef = ref;
                return step.buildWidget(context, ref);
              },
            ),
          ),
        );

        expect(
          find.byKey(const Key('test_wizard_step_widget')),
          findsOneWidget,
        );
        expect(capturedRef, isNotNull);
        expect(step.canAdvance(capturedRef!), isTrue);
        expect(step.canGoBack(capturedRef!), isTrue);
        expect(() => step.onManualAdvance(capturedRef!), returnsNormally);
      },
    );

    test('default executeAutoPlay returns true', () async {
      const step = _TestWizardStepDefinition();
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);

      final result = await step.executeAutoPlay(notifier);
      expect(result, isTrue);
    });

    test('default isStepComplete returns false', () {
      const step = _TestWizardStepDefinition();
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);

      expect(step.isStepComplete(notifier.model), isFalse);

      // Verify with an updated CanvasModel as well
      notifier.drawPixel(0, 0);
      expect(step.isStepComplete(notifier.model), isFalse);
    });
  });
}
