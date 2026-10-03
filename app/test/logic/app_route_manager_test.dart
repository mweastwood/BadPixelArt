import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/app_route_manager.dart';

class _TrackingTabController extends TabController {
  int animateToCallCount = 0;

  _TrackingTabController({
    required super.length,
    super.initialIndex = 0,
    required super.vsync,
  });

  @override
  void animateTo(int value, {Duration? duration, Curve curve = Curves.ease}) {
    animateToCallCount++;
    super.animateTo(value, duration: duration, curve: curve);
  }
}

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
    tabController = TabController(
      length: 3,
      initialIndex: 1,
      vsync: this,
    );
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

  group('updateUrlPath Unit Tests', () {
    test('valid tab indices execute without error', () {
      final routeManager = AppRouteManager();
      expect(() => routeManager.updateUrlPath(0), returnsNormally);
      expect(() => routeManager.updateUrlPath(1), returnsNormally);
      expect(() => routeManager.updateUrlPath(2), returnsNormally);
    });

    test(
      'out-of-bounds indices gracefully no-op without throwing exceptions',
      () {
        final routeManager = AppRouteManager();
        expect(() => routeManager.updateUrlPath(-1), returnsNormally);
        expect(() => routeManager.updateUrlPath(3), returnsNormally);
        expect(() => routeManager.updateUrlPath(99), returnsNormally);
      },
    );
  });

  group('handleUrlParameters Edge Cases', () {
    testWidgets(
      'trailing slash on /creations/ navigates to Creations Screen (tab index 0)',
      (tester) async {
        await tester.pumpWidget(
          _TestTabContainer(
            mockUri: Uri.parse('http://localhost:8080/creations/'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Creations Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'trailing slash on /logs/ navigates to Logs Screen (tab index 2)',
      (tester) async {
        await tester.pumpWidget(
          _TestTabContainer(mockUri: Uri.parse('http://localhost:8080/logs/')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Logs Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'path without leading slash correctly resolves to Creations Screen (tab index 0)',
      (tester) async {
        await tester.pumpWidget(
          _TestTabContainer(
            mockUri: Uri.parse(
              'http://localhost:8080',
            ).replace(path: 'creations'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Creations Screen'), findsOneWidget);
      },
    );

    testWidgets('root path / defaults to Canvas Screen (tab index 1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestTabContainer(mockUri: Uri.parse('http://localhost:8080/')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Canvas Screen'), findsOneWidget);
    });

    testWidgets(
      'unrecognized path /unknown defaults to Canvas Screen (tab index 1)',
      (tester) async {
        await tester.pumpWidget(
          _TestTabContainer(
            mockUri: Uri.parse('http://localhost:8080/unknown'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Canvas Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'unrecognized path /settings defaults to Canvas Screen (tab index 1)',
      (tester) async {
        await tester.pumpWidget(
          _TestTabContainer(
            mockUri: Uri.parse('http://localhost:8080/settings'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Canvas Screen'), findsOneWidget);
      },
    );

    test(
      'does not redundantly call animateTo when tabController.index matches targetIndex',
      () {
        final controller = _TrackingTabController(
          length: 3,
          initialIndex: 1,
          vsync: const TestVSync(),
        );
        final routeManager = AppRouteManager(
          mockUri: Uri.parse('http://localhost:8080/canvas'),
        );

        routeManager.handleUrlParameters(tabController: controller);

        expect(controller.index, 1);
        expect(controller.animateToCallCount, 0);

        controller.dispose();
      },
    );

    test(
      'calls animateTo when tabController.index does not match targetIndex',
      () {
        final controller = _TrackingTabController(
          length: 3,
          initialIndex: 0,
          vsync: const TestVSync(),
        );
        final routeManager = AppRouteManager(
          mockUri: Uri.parse('http://localhost:8080/canvas'),
        );

        routeManager.handleUrlParameters(tabController: controller);

        expect(controller.animateToCallCount, 1);

        controller.dispose();
      },
    );
  });
}
