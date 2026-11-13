import 'package:flutter/material.dart';

/// Preserves Home's empty fallback and FutureBuilder's retained-data behavior.
/// The caller owns loading, refresh and the supplied future.
class HomeOpsSnapshotView<T> extends StatelessWidget {
  const HomeOpsSnapshotView({
    super.key,
    required this.future,
    required this.emptyValue,
    required this.builder,
  });

  final Future<T> future;
  final T emptyValue;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        return builder(context, snapshot.data ?? emptyValue);
      },
    );
  }
}
