import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/evernote_owner_scope.dart';

void main() {
  testWidgets('owner switches discard cached rows, errors, and loading state',
      (tester) async {
    final owners = StreamController<String?>();
    addTearDown(owners.close);
    await tester.pumpWidget(
      MaterialApp(
        home: EvernoteOwnerScope(
          initialOwnerId: 'owner-a',
          ownerChanges: owners.stream,
          builder: (_) => const _CachedProbe(),
        ),
        ),
    );
    await tester.tap(find.text('Populate'));
    await tester.pump();
    expect(find.text('private rows / error / loading'), findsOneWidget);
    owners.add('owner-b');
    await tester.pump();
    expect(find.text('private rows / error / loading'), findsNothing);
    expect(find.text('empty'), findsOneWidget);
    await tester.tap(find.text('Populate'));
    await tester.pump();
    owners.add(null);
    await tester.pump();
    expect(find.text('private rows / error / loading'), findsNothing);
    owners.add('owner-a');
    await tester.pump();
    expect(find.text('empty'), findsOneWidget);
  });

  testWidgets('old asynchronous completion cannot repopulate a new owner',
      (tester) async {
    final owners = StreamController<String?>();
    final release = Completer<void>();
    var builds = 0;
    addTearDown(owners.close);
    await tester.pumpWidget(
      MaterialApp(
        home: EvernoteOwnerScope(
          initialOwnerId: 'owner-a',
          ownerChanges: owners.stream,
          builder: (_) => _CachedProbe(
            release: builds++ == 0 ? release.future : null,
          ),
        ),
        ),
    );
    owners.add('owner-b');
    await tester.pump();
    expect(find.text('empty'), findsOneWidget);
    release.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('empty'), findsOneWidget);
    expect(find.text('private rows / error / loading'), findsNothing);
  });
}

class _CachedProbe extends StatefulWidget {
  final Future<void>? release;
  const _CachedProbe({this.release});

  @override
  State<_CachedProbe> createState() => _CachedProbeState();
}

class _CachedProbeState extends State<_CachedProbe> {
  String value = 'empty';

  @override
  void initState() {
    super.initState();
    widget.release?.then((_) {
      if (mounted) setState(() => value = 'private rows / error / loading');
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value),
          TextButton(
            onPressed: () => setState(() {
              value = 'private rows / error / loading';
            }),
            child: const Text('Populate'),
          ),
        ],
      );
}
