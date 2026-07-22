import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    // ignore: deprecated_member_use
    return WebDatabase('bad_pixel_art');
  });
}
