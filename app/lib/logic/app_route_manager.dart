import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AppRouteManager {
  final Uri? mockUri;

  AppRouteManager({this.mockUri});

  void updateUrlPath(int index) {
    if (!kIsWeb) return;
    String path;
    switch (index) {
      case 0:
        path = '/creations';
        break;
      case 1:
        path = '/canvas';
        break;
      case 2:
        path = '/logs';
        break;
      default:
        return;
    }
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(path),
      replace: true,
    );
  }

  void handleUrlParameters({required TabController tabController}) {
    final uri = mockUri ?? Uri.base;

    String path = uri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    int targetIndex = 1; // Default to /canvas
    if (path == 'creations') {
      targetIndex = 0;
    } else if (path == 'logs') {
      targetIndex = 2;
    } else if (path == 'canvas') {
      targetIndex = 1;
    }

    if (tabController.index != targetIndex) {
      tabController.animateTo(targetIndex);
    }
    updateUrlPath(targetIndex);
  }
}
