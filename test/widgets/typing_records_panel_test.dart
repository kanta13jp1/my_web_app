import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/typing_game.dart';
import 'package:my_web_app/services/typing_score_service.dart';
import 'package:my_web_app/widgets/typing_records_panel.dart';

class FakeStore implements TypingScoreStore {
  @override
  String? accountId = 'owner';
  final auth = StreamController<String?>.broadcast();
  @override
  Stream<String?> get accountChanges => auth.stream;
  final calls = <String>[];
  bool fail = false;
  bool published = false;
  bool deleted = false;
  @override
  Future<void> save(TypingRunReport report) async {
    calls.add('save:${report.id}');
    if (fail) throw StateError('offline');
  }

  @override
  Future<List<Map<String, dynamic>>> mine() async => deleted
      ? []
      : [
          {
            'id': 'run',
            'mode': 'challenge',
            'can_publish': true,
            'score': 60,
            'alias': published ? 'TypingFan' : null,
          },
        ];
  @override
  Future<List<Map<String, dynamic>>> ranking() async => [
        {'alias': 'TypingFan', 'score': 60, 'accuracy': 100},
      ];
  @override
  Future<void> publish(String id, String alias) async {
    calls.add('publish:$alias');
    published = true;
  }

  @override
  Future<void> withdraw(String id) async {
    calls.add('withdraw');
    published = false;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete');
    deleted = true;
  }
}

void main() {
  testWidgets('records controls fit a narrow screen in both UI languages',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FakeStore();
    addTearDown(store.auth.close);
    for (final english in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TypingRecordsPanel(
                  store: store,
                  report: null,
                  english: english,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  Future<void> show(WidgetTester tester, FakeStore store) async {
    final game = TypingGame()..start();
    game.updateElapsed(TypingGame.duration);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TypingRecordsPanel(
              store: store,
              report: TypingRunReport.fromGame(game),
              english: true,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('saving never publishes and a failed save retries the same ID',
      (tester) async {
    final store = FakeStore();
    addTearDown(store.auth.close);
    await show(tester, store);
    expect(store.calls, isEmpty);
    store.fail = true;
    await tester.tap(find.text('Save this result privately'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save'), findsOneWidget);
    store.fail = false;
    await tester.tap(find.text('Save this result privately'));
    await tester.pumpAndSettle();
    expect(store.calls.length, 2);
    expect(store.calls[0], store.calls[1]);
    expect(store.published, isFalse);
    expect(find.text('Choose publication'), findsOneWidget);
  });

  testWidgets('publication requires a separate confirmation and alias',
      (tester) async {
    final store = FakeStore();
    addTearDown(store.auth.close);
    await show(tester, store);
    await tester.tap(find.text('Load my history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose publication'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.calls, isEmpty);
    await tester.tap(find.text('Choose publication'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'TypingFan');
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(store.calls, ['publish:TypingFan']);
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(store.calls, ['publish:TypingFan']);
    await tester.tap(find.text('Confirm withdrawal'));
    await tester.pumpAndSettle();
    expect(store.calls.last, 'withdraw');
    expect(find.text('Withdraw'), findsNothing);
  });

  testWidgets(
    'private deletion requires an explicit irreversible-action confirmation',
    (tester) async {
      final store = FakeStore();
      addTearDown(store.auth.close);
      await show(tester, store);
      await tester.tap(find.text('Load my history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete record'));
      await tester.pumpAndSettle();
      expect(find.textContaining('There is no undo here'), findsOneWidget);
      expect(store.calls, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.calls, isEmpty);
      await tester.tap(find.text('Delete record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      expect(store.calls, ['delete']);
      expect(find.text('Choose publication'), findsNothing);
    },
  );

  testWidgets(
    'changing account during deletion confirmation prevents the write',
    (tester) async {
      final store = FakeStore();
      addTearDown(store.auth.close);
      await show(tester, store);
      await tester.tap(find.text('Load my history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete record'));
      await tester.pumpAndSettle();
      store.accountId = 'other-owner';
      store.auth.add(store.accountId);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      expect(store.calls, isEmpty);
    },
  );

  testWidgets('sign out immediately hides private history and blocks saving',
      (tester) async {
    final store = FakeStore();
    addTearDown(store.auth.close);
    await show(tester, store);
    await tester.tap(find.text('Load my history'));
    await tester.pumpAndSettle();
    expect(find.text('Choose publication'), findsOneWidget);
    store.accountId = null;
    store.auth.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Choose publication'), findsNothing);
    await tester.tap(find.text('Save this result privately'));
    await tester.pumpAndSettle();
    expect(find.text('Please sign in first.'), findsOneWidget);
    expect(store.calls, isEmpty);
  });
}
