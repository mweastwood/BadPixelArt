import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/prompts.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPaletteAiService extends AiService {
  AiCoreStatus status = AiCoreStatus.available;

  @override
  Future<AiCoreStatus> checkStatus() async => status;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    if (temperature <= 0.5 &&
        (prompt.contains('16 colors') || prompt.contains('8 colors'))) {
      final List<String> mockPalette = List.generate(8, (i) {
        final val = (i * 0x22).toRadixString(16).padLeft(2, '0');
        return '#$val$val$val';
      });
      return '["${mockPalette.join('", "')}"]';
    }
    return null;
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

void main() {
  group('Canvas Palette Tests', () {
    late MockPaletteAiService mockAiService;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAiService = MockPaletteAiService();
      container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(mockAiService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('selectPalette resets canvas and changes palette', () {
      final notifier = container.read(canvasStateProvider.notifier);

      notifier.drawPixel(5, 5); // Draw a pixel
      expect(container.read(canvasStateProvider).undoStack, isNotEmpty);

      notifier.selectPalette('grayscale');
      final model = container.read(canvasStateProvider);
      expect(model.paletteName, equals('grayscale'));
      expect(model.palette.length, equals(4));
      expect(model.grid[5][5], equals(0)); // Reset canvas check
      expect(model.undoStack, isEmpty);
    });

    test('parsePaletteColors parses clean JSON list correctly', () {
      const jsonResponse = '["#ff0000", "#00ff00", "#0000ff"]';
      final colors = parsePaletteColors(jsonResponse);
      expect(colors.length, equals(8));
      expect(colors[0], equals(const Color(0xFFFF0000)));
      expect(colors[1], equals(const Color(0xFF00FF00)));
      expect(colors[2], equals(const Color(0xFF0000FF)));
    });

    test('parsePaletteColors extracts colors via regex fallback', () {
      const textResponse =
          'Here are the suggested colors: #ff55aa and #00bbcc.';
      final colors = parsePaletteColors(textResponse);
      expect(colors.length, equals(8));
      expect(colors[0], equals(const Color(0xFFFF55AA)));
      expect(colors[1], equals(const Color(0xFF00BBCC)));
    });

    test(
      'suggestPaletteFromReference triggers suggestion and shows palette',
      () async {
        final notifier = container.read(canvasStateProvider.notifier);
        final refBmp = Uint8List.fromList([1, 2, 3]);
        notifier.setReferenceImage(refBmp);

        await notifier.suggestPaletteFromReference();

        final state = container.read(canvasStateProvider);
        expect(state.suggestedPalette, isNotNull);
        expect(state.suggestedPalette!.length, equals(8));
        expect(state.showPaletteSuggestion, isTrue);
      },
    );

    test('acceptSuggestedPalette updates palette and resets canvas', () {
      final notifier = container.read(canvasStateProvider.notifier);
      final suggested = List.generate(8, (i) => Color(0xFF000000 + i));

      notifier.state = notifier.state.copyWith(
        suggestedPalette: suggested,
        showPaletteSuggestion: true,
      );

      notifier.acceptSuggestedPalette();

      final state = container.read(canvasStateProvider);
      expect(state.paletteName, equals('suggested'));
      expect(state.palette, equals(suggested));
      expect(state.showPaletteSuggestion, isFalse);
      expect(state.selectedColorIndex, equals(0));
    });

    test('rejectSuggestedPalette clears suggestion', () {
      final notifier = container.read(canvasStateProvider.notifier);
      final suggested = List.generate(16, (i) => Color(0xFF000000 + i));

      notifier.state = notifier.state.copyWith(
        suggestedPalette: suggested,
        showPaletteSuggestion: true,
      );

      notifier.rejectSuggestedPalette();

      final state = container.read(canvasStateProvider);
      expect(state.showPaletteSuggestion, isFalse);
      expect(state.suggestedPalette, isNull);
    });
  });
}
