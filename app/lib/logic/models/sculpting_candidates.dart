import 'dart:math';
import 'package:flutter/foundation.dart';

@immutable
class SculptingCandidates {
  final List<Point<int>> remove;
  final List<Point<int>> add;

  const SculptingCandidates({this.remove = const [], this.add = const []});

  static const SculptingCandidates empty = SculptingCandidates();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SculptingCandidates) return false;
    return listEquals(remove, other.remove) && listEquals(add, other.add);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(remove), Object.hashAll(add));
}
