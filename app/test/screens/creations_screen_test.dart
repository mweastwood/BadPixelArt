import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/screens/creations_screen.dart';
import 'package:bad_pixel_art/widgets/creations_drawer.dart';
import '../test_helper.dart';

void main() {
  group('CreationsScreen Unit & Golden Tests', () {
    testWidgets('renders CreationsScreen with CreationsDrawer child', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const CreationsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CreationsDrawer), findsOneWidget);
      expect(find.text('Creations Gallery'), findsOneWidget);
    });

    testWidgets(
      'invokes onCreationSelected callback when + New Canvas is tapped',
      (tester) async {
        bool selected = false;
        await tester.pumpWidget(
          buildTestableWidget(
            child: CreationsScreen(
              onCreationSelected: () {
                selected = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('New Canvas'));
        await tester.pumpAndSettle();

        expect(selected, isTrue);
      },
    );

    testWidgets('CreationsScreen golden render', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const CreationsScreen()),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(CreationsScreen),
        matchesGoldenFile('goldens/creations_screen.png'),
      );
    }, tags: 'golden');
  });
}
