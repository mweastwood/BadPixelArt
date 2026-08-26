import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/widgets/export_art_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyGrid = [
    [1, 0, 2],
    [0, 1, 0],
    [2, 0, 1],
  ];
  final dummyPalette = [const Color(0xFFFF0000), const Color(0xFF0000FF)];

  testWidgets('ExportArtDialog renders all UI elements properly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportArtDialog(
            grid: dummyGrid,
            palette: dummyPalette,
            initialTitle: 'Dragon Sprite',
          ),
        ),
      ),
    );

    // Verify Title & Preview
    expect(find.text('Export Pixel Art'), findsOneWidget);
    expect(find.byKey(const ValueKey('export_art_dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('export_filename_input')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Dragon_Sprite'), findsOneWidget);

    // Verify format segmented button
    expect(
      find.byKey(const ValueKey('export_format_segmented_button')),
      findsOneWidget,
    );
    expect(find.text('PNG (Raster)'), findsOneWidget);
    expect(find.text('SVG (Vector)'), findsOneWidget);

    // Verify scale options
    expect(find.text('Scale / Resolution'), findsOneWidget);
    expect(find.byKey(const ValueKey('scale_chip_1x')), findsOneWidget);
    expect(find.byKey(const ValueKey('scale_chip_8x')), findsOneWidget);
    expect(find.byKey(const ValueKey('scale_chip_16x')), findsOneWidget);

    // Verify transparency switch
    expect(
      find.byKey(const ValueKey('export_transparency_switch')),
      findsOneWidget,
    );
    expect(find.text('Transparent Background'), findsOneWidget);

    // Verify Buttons
    expect(find.byKey(const ValueKey('export_cancel_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export_confirm_button')), findsOneWidget);
  });

  testWidgets(
    'ExportArtDialog switches format and updates file extension suffix',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportArtDialog(
              grid: dummyGrid,
              palette: dummyPalette,
              initialTitle: 'Hero',
            ),
          ),
        ),
      );

      expect(find.text('.png'), findsOneWidget);

      // Tap SVG format
      await tester.tap(find.text('SVG (Vector)'));
      await tester.pumpAndSettle();

      expect(find.text('.svg'), findsOneWidget);
    },
  );

  testWidgets('ExportArtDialog updates scale and resolution label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportArtDialog(
            grid: dummyGrid, // 3x3
            palette: dummyPalette,
            initialTitle: 'Hero',
          ),
        ),
      ),
    );

    // Default scale is 8x -> 3*8 = 24x24 px
    expect(find.text('24×24 px'), findsOneWidget);

    // Select 16x -> 3*16 = 48x48 px
    await tester.tap(find.byKey(const ValueKey('scale_chip_16x')));
    await tester.pumpAndSettle();

    expect(find.text('48×48 px'), findsOneWidget);
  });

  testWidgets('ExportArtDialog toggles transparency switch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportArtDialog(
            grid: dummyGrid,
            palette: dummyPalette,
            initialTitle: 'Hero',
          ),
        ),
      ),
    );

    final switchFinder = find.byKey(
      const ValueKey('export_transparency_switch'),
    );
    expect(switchFinder, findsOneWidget);

    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      find.text('Fills canvas background with solid dark color'),
      findsOneWidget,
    );
  });

  testWidgets('ExportArtDialog cancel button pops dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showExportArtDialog(
                context,
                grid: dummyGrid,
                palette: dummyPalette,
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('export_art_dialog')), findsOneWidget);

    expect(find.byKey(const ValueKey('export_cancel_button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('export_cancel_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('export_art_dialog')), findsNothing);
  });

  testWidgets(
    'ExportArtDialog correctly displays dimensions for non-square grids',
    (tester) async {
      final rectangularGrid = List.generate(16, (_) => List.filled(32, 1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportArtDialog(
              grid: rectangularGrid,
              palette: dummyPalette,
              initialTitle: 'Rectangle',
            ),
          ),
        ),
      );

      expect(find.text('32×16 px original ➔ 256×128 px (8x)'), findsOneWidget);
      expect(find.text('256×128 px'), findsOneWidget);
    },
  );
}
