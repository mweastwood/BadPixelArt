import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/app_route_manager.dart';

class _TestTabContainer extends StatefulWidget {
  final Uri? mockUri;
  const _TestTabContainer({this.mockUri});

  @override
  State<_TestTabContainer> createState() => _TestTabContainerState();
}

class _TestTabContainerState extends State<_TestTabContainer>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  late AppRouteManager routeManager;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, initialIndex: 1, vsync: this);
    routeManager = AppRouteManager(mockUri: widget.mockUri);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        routeManager.handleUrlParameters(tabController: tabController);
      }
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: TabBarView(
          controller: tabController,
          children: const [
            Text('Creations Screen'),
            Text('Canvas Screen'),
            Text('Logs Screen'),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('AppRouteManager Unit Tests', () {
    testWidgets(
      'defaults to /canvas (tab index 1) when URL is root or /canvas',
      (tester) async {
        await tester.pumpWidget(
          _TestTabContainer(mockUri: Uri.parse('http://localhost:8080/canvas')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Canvas Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to /creations (tab index 0) when URL path is /creations',
      (tester) async {
        await tester.pumpWidget(
          _TestTabContainer(
            mockUri: Uri.parse('http://localhost:8080/creations'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Creations Screen'), findsOneWidget);
      },
    );

    testWidgets('navigates to /logs (tab index 2) when URL path is /logs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestTabContainer(mockUri: Uri.parse('http://localhost:8080/logs')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Logs Screen'), findsOneWidget);
    });
  });
}
