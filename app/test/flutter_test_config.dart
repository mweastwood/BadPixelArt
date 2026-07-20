import 'dart:async';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:drift/native.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  AppDatabaseHelper.db = AppDatabase(NativeDatabase.memory());
  return GoldenToolkit.runWithConfiguration(() async {
    await testMain();
  }, config: GoldenToolkitConfiguration());
}
