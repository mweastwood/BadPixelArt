import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/creations_drawer.dart';

class CreationsScreen extends ConsumerWidget {
  final VoidCallback? onCreationSelected;

  const CreationsScreen({super.key, this.onCreationSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CreationsDrawer(onCreationSelected: onCreationSelected),
    );
  }
}
