import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    try {
      // ignore: deprecated_member_use, experimental_member_use
      return WebDatabase.withStorage(
        // ignore: experimental_member_use
        DriftWebStorage.indexedDb('bad_pixel_art'),
      );
    } catch (e) {
      debugPrint(
        'WebDatabase initialization failed: $e, falling back to volatile.',
      );
      // ignore: deprecated_member_use
      return WebDatabase.withStorage(DriftWebStorage.volatile());
    }
  });
}
