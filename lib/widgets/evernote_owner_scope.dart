import 'package:flutter/material.dart';

/// Discards all cached UI state when the authenticated owner changes.
class EvernoteOwnerScope extends StatelessWidget {
  final String? initialOwnerId;
  final Stream<String?> ownerChanges;
  final WidgetBuilder builder;

  const EvernoteOwnerScope({
    super.key,
    required this.initialOwnerId,
    required this.ownerChanges,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
        stream: ownerChanges,
        initialData: initialOwnerId,
        builder: (context, snapshot) => KeyedSubtree(
          key: ValueKey<String?>(snapshot.hasError ? null : snapshot.data),
          child: Builder(builder: builder),
        ),
      );
}

bool isEvernoteOwnerActive({
  required bool mounted,
  required String? currentOwnerId,
  required String expectedOwnerId,
}) =>
    mounted && currentOwnerId != null && currentOwnerId == expectedOwnerId;
