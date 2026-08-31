import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/screens/creations_screen.dart';
import 'package:bad_pixel_art/screens/canvas_screen.dart';
import 'package:bad_pixel_art/screens/logs_screen.dart';
import 'package:bad_pixel_art/screens/model_options_screen.dart';
import 'package:bad_pixel_art/screens/reference_library_screen.dart';
import 'package:bad_pixel_art/widgets/grid_size_selection_card.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/logic/services/share_receiver_service.dart';

import '../test_helper.dart';

void main() {
  group('PixelArtScreen Navigation, Drawer, & FAB Tests', () {
    testWidgets('renders full responsive layout components', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );

      // Verify the appBar title is visible
      expect(find.text('Bad Pixel Art'), findsOneWidget);
    });

    testWidgets(
      'renders 3 bottom navigation destinations (Canvas, Creations, Logs) with correct icons',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );

        // Verify NavigationBar destinations (Creations: 0, Canvas: 1, Logs: 2)
        final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(navBar.destinations, hasLength(3));

        final dests = navBar.destinations.cast<NavigationDestination>();
        expect(dests[0].label, equals('Creations'));
        expect(dests[1].label, equals('Canvas'));
        expect(dests[2].label, equals('Logs'));

        // Verify destination icons
        expect(
          (dests[0].icon as Icon).icon,
          equals(Icons.collections_outlined),
        );
        expect((dests[1].icon as Icon).icon, equals(Icons.palette_outlined));
        expect(
          dests[2].icon,
          isA<Icon>().having(
            (i) => i.icon,
            'icon',
            equals(Icons.chat_bubble_outline),
          ),
        );
      },
    );

    testWidgets(
      'switches between Canvas, Creations, and Logs tabs on bottom navigation tap',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );

        // Initially on Canvas tab (CanvasScreen visible)
        expect(find.byType(CanvasScreen), findsOneWidget);
        expect(find.byType(GridSizeSelectionCard), findsOneWidget);

        // Tap Creations tab (index 0)
        await tester.tap(find.text('Creations'));
        await tester.pumpAndSettle();

        // Verify CreationsScreen is visible
        expect(find.byType(CreationsScreen), findsOneWidget);
        expect(find.text('Creations Gallery'), findsOneWidget);

        // Tap Logs tab (index 2)
        await tester.tap(find.text('Logs'));
        await tester.pumpAndSettle();

        // Verify LogsScreen is visible
        expect(find.byType(LogsScreen), findsOneWidget);
        expect(find.textContaining('Conversation History'), findsOneWidget);

        // Tap Canvas tab (index 1) to return
        await tester.tap(find.text('Canvas'));
        await tester.pumpAndSettle();

        expect(find.byType(CanvasScreen), findsOneWidget);
      },
    );

    testWidgets('shows correct FloatingActionButton per tab', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );

      // Default on Canvas tab (index 1): wizard navigation FAB is visible
      expect(find.byKey(const ValueKey('wizard_next_fab')), findsOneWidget);
      expect(find.byKey(const ValueKey('export_logs_fab')), findsNothing);
      expect(find.byKey(const ValueKey('new_creation_fab')), findsNothing);

      // Tap Creations tab (index 0)
      await tester.tap(find.text('Creations'));
      await tester.pumpAndSettle();

      // New Creation FAB visible on Creations tab
      expect(find.byKey(const ValueKey('new_creation_fab')), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard_next_fab')), findsNothing);

      // Tap Logs tab (index 2)
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      // Export FAB is visible on Logs tab, wizard FAB is not
      expect(find.byKey(const ValueKey('export_logs_fab')), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard_next_fab')), findsNothing);

      // Return to Canvas tab (index 1)
      await tester.tap(find.text('Canvas'));
      await tester.pumpAndSettle();

      // Wizard FAB is visible again
      expect(find.byKey(const ValueKey('wizard_next_fab')), findsOneWidget);
    });

    testWidgets(
      'tapping New Creation FAB in Creations tab resets wizard step to Step 0 and navigates back to Canvas tab',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );

        // Advance wizard to Step 1 (Reference & Prompt) by tapping Next FAB
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(find.byType(ReferenceImagePrompt), findsOneWidget);

        // Switch to Creations tab
        await tester.tap(find.text('Creations'));
        await tester.pumpAndSettle();

        expect(find.text('Creations Gallery'), findsOneWidget);

        // Tap New Creation FAB
        await tester.tap(find.byKey(const ValueKey('new_creation_fab')));
        await tester.pumpAndSettle();

        // Should auto-navigate back to Canvas tab and reset wizard to Step 0 (GridSizeSelectionCard)
        expect(find.byType(GridSizeSelectionCard), findsOneWidget);
        expect(find.text('Canvas Resolution'), findsOneWidget);
      },
    );

    testWidgets('renders Export Logs FAB on Logs screen tab', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );

      // Default active tab is Canvas (tab index 1)
      expect(find.byKey(const ValueKey('export_logs_fab')), findsNothing);

      // Tap Logs tab (tab index 2)
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      // Verify Export Logs FAB appears on Logs tab
      expect(find.byKey(const ValueKey('export_logs_fab')), findsOneWidget);
    });

    testWidgets('opens hamburger drawer and displays version info', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );
      await tester.pump();

      // Open drawer using hamburger button
      final drawerButton = find.byTooltip('Open navigation menu');
      expect(drawerButton, findsOneWidget);
      await tester.tap(drawerButton);
      await tester.pumpAndSettle();

      // Verify drawer header and tiles
      expect(
        find.byKey(const ValueKey('app_hamburger_drawer')),
        findsOneWidget,
      );
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Creations Gallery'), findsOneWidget);
      expect(find.text('Canvas Studio'), findsOneWidget);
      expect(find.text('Conversation Logs'), findsOneWidget);
      expect(find.text('Model Options'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('v0.0.0-dev'), findsOneWidget);
    });

    testWidgets(
      'tapping model_options_button in AppBar pushes ModelOptionsScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('model_options_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('model_options_button')));
        await tester.pumpAndSettle();

        expect(find.byType(ModelOptionsScreen), findsOneWidget);
        expect(find.text('AI Engine'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping drawer_model_options_tile in drawer pushes ModelOptionsScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );
        await tester.pump();

        // Open drawer
        final drawerButton = find.byTooltip('Open navigation menu');
        await tester.tap(drawerButton);
        await tester.pumpAndSettle();

        // Tap drawer model options tile
        expect(
          find.byKey(const ValueKey('drawer_model_options_tile')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('drawer_model_options_tile')),
        );
        await tester.pumpAndSettle();

        // Verify ModelOptionsScreen is pushed
        expect(find.byType(ModelOptionsScreen), findsOneWidget);
        expect(find.text('AI Engine'), findsOneWidget);
      },
    );

    testWidgets(
      'handles incoming shared media items via ShareReceiverService without errors and displays snackbar',
      (tester) async {
        final fakeService = FakeShareReceiverService();

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: [
              shareReceiverServiceProvider.overrideWithValue(fakeService),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch away from Canvas tab to Creations tab (index 0)
        await tester.tap(find.text('Creations'));
        await tester.pumpAndSettle();

        // Emit simulated shared image
        final now = DateTime.now();
        final fakeImage = ReferenceImage(
          id: 1,
          imageData: Uint8List.fromList([1, 2, 3]),
          bmpData: Uint8List.fromList([1, 2, 3]),
          title: 'Shared Pixel Sword',
          prompt: 'a glowing sword',
          source: 'gemini',
          createdAt: now,
          updatedAt: now,
        );
        fakeService.emitSharedImage(fakeImage);
        await tester.pumpAndSettle();

        // Verify SnackBar was shown and tab switched back to Canvas (index 1)
        expect(
          find.text(
            'Imported "Shared Pixel Sword" from Gemini & set as reference',
          ),
          findsOneWidget,
        );
        expect(find.text('View Library'), findsOneWidget);

        // Tap 'View Library' action in SnackBar
        await tester.tap(find.text('View Library'));
        await tester.pumpAndSettle();

        expect(find.byType(ReferenceLibraryScreen), findsOneWidget);
      },
    );

    testWidgets(
      'PixelArtScreen initializes cleanly when using real shareReceiverServiceProvider with setupMockShareReceiverChannel()',
      (tester) async {
        setupMockShareReceiverChannel();
        addTearDown(clearMockShareReceiverChannel);

        // Do not override shareReceiverServiceProvider, so the real provider is instantiated
        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: const [],
          ),
        );
        await tester.pumpAndSettle();

        // Verify screen renders cleanly
        expect(find.text('Bad Pixel Art'), findsOneWidget);
      },
    );
  });
}
