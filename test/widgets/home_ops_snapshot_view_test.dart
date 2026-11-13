import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_ops_snapshot_view.dart';

Widget view(Future<List<int>> future) {
  return MaterialApp(
    home: HomeOpsSnapshotView<List<int>>(
      future: future,
      emptyValue: const [],
      builder: (context, value) => Text('days: ${value.length}'),
    ),
  );
}

void main() {
  testWidgets('waiting empty and data', (tester) async {
    final pending = Completer<List<int>>();
    await tester.pumpWidget(view(pending.future));
    expect(find.text('days: 0'), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('days: 0'), findsOneWidget);
    final loaded = Completer<List<int>>();
    await tester.pumpWidget(view(loaded.future));
    loaded.complete([1, 2, 3]);
    await tester.pumpAndSettle();
    expect(find.text('days: 3'), findsOneWidget);
  });

  testWidgets('refresh retains prior data', (tester) async {
    final first = Completer<List<int>>();
    await tester.pumpWidget(view(first.future));
    first.complete([1, 2]);
    await tester.pumpAndSettle();
    final next = Completer<List<int>>();
    await tester.pumpWidget(view(next.future));
    expect(find.text('days: 2'), findsOneWidget);
    await tester.pumpWidget(view(next.future));
    expect(find.text('days: 2'), findsOneWidget);
    next.complete([4]);
    await tester.pumpAndSettle();
    expect(find.text('days: 1'), findsOneWidget);
  });

  testWidgets('old completion is ignored', (tester) async {
    final old = Completer<List<int>>();
    final current = Completer<List<int>>();
    await tester.pumpWidget(view(old.future));
    await tester.pumpWidget(view(current.future));
    old.complete([1]);
    await tester.pumpAndSettle();
    expect(find.text('days: 0'), findsOneWidget);
    current.complete([1, 2]);
    await tester.pumpAndSettle();
    expect(find.text('days: 2'), findsOneWidget);
  });

  testWidgets('error uses empty fallback', (tester) async {
    final first = Completer<List<int>>();
    await tester.pumpWidget(view(first.future));
    first.complete([1]);
    await tester.pumpAndSettle();
    final failed = Completer<List<int>>();
    await tester.pumpWidget(view(failed.future));
    expect(find.text('days: 1'), findsOneWidget);
    failed.completeError(StateError('private diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('days: 0'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
