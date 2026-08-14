import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:drift/native.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';

class TolerantLocalFileComparator extends LocalFileComparator {
  final double tolerance;

  TolerantLocalFileComparator(super.testFile, {this.tolerance = 0.01});

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= tolerance) {
      return true;
    }
    if (!result.passed) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return result.passed;
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  if (goldenFileComparator is LocalFileComparator) {
    final basedir = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = TolerantLocalFileComparator(
      basedir.resolve('test.dart'),
      tolerance: 0.01,
    );
  }
  AppDatabaseHelper.db = AppDatabase(NativeDatabase.memory());
  return GoldenToolkit.runWithConfiguration(() async {
    await testMain();
  }, config: GoldenToolkitConfiguration());
}
