import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../canvas_state.dart';
import '../wizard_state.dart';

/// Abstract definition for a generic, modular wizard step.
abstract class WizardStepDefinition {
  const WizardStepDefinition();

  /// The step enum or identifier.
  WizardStep get step;

  /// Human-readable title for this step.
  String get title;

  /// Optional description for this step.
  String? get description => null;

  /// Builds the UI card or panel widget for this step.
  Widget buildWidget(BuildContext context, WidgetRef ref);

  /// Checks whether manual forward navigation is allowed.
  bool canAdvance(WidgetRef ref) => true;

  /// Checks whether manual backward navigation is allowed.
  bool canGoBack(WidgetRef ref) => true;

  /// Hook executed on manual advance before navigating forward.
  void onManualAdvance(WidgetRef ref) {}

  /// Executes automated step processing during Auto-Play.
  /// Returns `true` if step succeeded and auto-play should advance,
  /// or `false` if step failed / was incomplete.
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async => true;

  /// Checks if this step is already satisfied/complete.
  bool isStepComplete(CanvasModel model) => false;
}
