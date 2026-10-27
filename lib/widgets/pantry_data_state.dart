import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pantry_provider.dart';
import 'message_state.dart';

/// Every surface backed by the household database uses the same recovery flow.
class PantryDataState extends StatelessWidget {
  const PantryDataState({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    if (pantry.isLoading && !pantry.hasLoaded) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading household'),
      );
    }
    if (pantry.errorMessage != null && !pantry.hasLoaded) {
      return MessageState(
        icon: Icons.error_outline,
        title: 'Household unavailable',
        message: pantry.errorMessage!,
        actionLabel: 'Try again',
        actionIcon: Icons.refresh,
        onAction: pantry.loadItems,
      );
    }
    return Column(
      children: [
        if (pantry.isLoading)
          const LinearProgressIndicator(semanticsLabel: 'Refreshing household'),
        if (pantry.errorMessage != null)
          MaterialBanner(
            leading: const Icon(Icons.error_outline),
            content: Semantics(
              liveRegion: true,
              child: Text(
                'Household unavailable. ${pantry.errorMessage} Showing the last loaded data.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: pantry.loadItems,
                child: const Text('Try again'),
              ),
            ],
          ),
        Expanded(child: child),
      ],
    );
  }
}
