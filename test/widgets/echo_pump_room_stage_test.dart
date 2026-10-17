import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_game.dart';
import 'package:my_web_app/widgets/echo_pump_room_stage.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    VoidCallback? step,
    ValueChanged<PumpRoom>? move,
    bool reduced = false,
    double textScale = 1,
    AssetBundle? bundle,
  }) async {
    final stage = EchoPumpRoomStage(onFootstep: step, onMove: move);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: bundle == null
                ? stage
                : DefaultAssetBundle(bundle: bundle, child: stage),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('preloads before input and keeps the actor while art is pending',
      (tester) async {
    final bundle = _DelayedWalkArt();
    await show(tester, bundle: bundle);
    expect(bundle.requested, isTrue);
    Finder actorImage(String asset) => find.descendant(
          of: find.byKey(const Key('echo-room-actor')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == asset,
          ),
        );
    const standing = 'assets/echo_pump/character_technician.png';
    const walking = 'assets/echo_pump/character_walk.png';
    expect(actorImage(standing), findsOneWidget);
    await tester.tap(find.text('保守メモを調べる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('歩行中…'), findsOneWidget);
    expect(actorImage(standing), findsOneWidget);
    expect(actorImage(walking), findsNothing);
    await tester.runAsync(() async {
      bundle.complete(await rootBundle.load(walking));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(actorImage(walking), findsOneWidget);
    expect(actorImage(standing), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('夜間保守メモ 1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed preload keeps the actor and does not block the memo',
      (tester) async {
    final bundle = _DelayedWalkArt();
    await show(tester, bundle: bundle);
    bundle.fail();
    await tester.pump();
    await tester.tap(find.text('保守メモを調べる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('歩行中…'), findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const Key('echo-room-actor')),
          matching: find.byType(Image),
        ),
        findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('夜間保守メモ 1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preload completion after leaving does not update disposed state',
      (tester) async {
    final bundle = _DelayedWalkArt();
    await show(tester, bundle: bundle);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(() async {
      bundle.complete(
          await rootBundle.load('assets/echo_pump/character_walk.png'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('approach animates, emits steps once and opens a paged memo',
      (tester) async {
    var steps = 0;
    await show(tester, step: () => steps++);
    final before = tester
        .widget<Positioned>(find.byKey(const Key('echo-room-actor')))
        .left;
    await tester.tap(find.text('保守メモを調べる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final after =
        tester.widget<Positioned>(find.byKey(const Key('echo-room-actor'))).top;
    expect(after, lessThan(104));
    expect(before, isNotNull);
    expect(find.text('歩行中…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '中央廊下の扉を調べる'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpAndSettle();
    expect(steps, 2);
    expect(find.text('夜間保守メモ 1 / 2'), findsOneWidget);
    await tester.tap(find.text('次のページ'));
    await tester.pumpAndSettle();
    expect(find.text('夜間保守メモ 2 / 2'), findsOneWidget);
    await tester.tap(find.text('メモを閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保守メモを調べる'));
    await tester.pumpAndSettle();
    expect(steps, 2);
    expect(find.text('夜間保守メモ 1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera and memo do not advance turns; door commits exactly once',
      (tester) async {
    final game = EchoPumpGame();
    var moves = 0;
    await show(
      tester,
      move: (room) {
        moves++;
        game.move(room);
      },
    );
    await tester.tap(find.text('設備寄りに見る'));
    await tester.pumpAndSettle();
    expect(find.text('全景へ'), findsOneWidget);
    expect(game.turn, 0);
    await tester.tap(find.text('中央廊下の扉を調べる'));
    await tester.pumpAndSettle();
    expect(find.text('中央廊下の扉'), findsOneWidget);
    expect(game.turn, 0);
    await tester.tap(find.text('扉を開けて進む'));
    await tester.pumpAndSettle();
    expect(moves, 1);
    expect(game.turn, 1);
    expect(game.room, PumpRoom.hall);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'backgrounding cancels the walk and does not open a dialog on return',
      (tester) async {
    var steps = 0;
    await show(tester, step: () => steps++);
    await tester.tap(find.text('中央廊下の扉を調べる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    final stopped = steps;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(steps, stopped);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('歩行中…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during walking stops callbacks and disposes the ticker',
      (tester) async {
    var steps = 0;
    await show(tester, step: () => steps++);
    await tester.tap(find.text('中央廊下の扉を調べる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final stopped = steps;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(steps, stopped);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1120.0]) {
    testWidgets('reduced motion and 2x text work at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var steps = 0;
      await show(tester, reduced: true, textScale: 2, step: () => steps++);
      await tester.tap(find.text('保守メモを調べる'));
      await tester.pumpAndSettle();
      expect(steps, 0);
      expect(find.text('夜間保守メモ 1 / 2'), findsOneWidget);
      await tester.ensureVisible(find.text('次のページ'));
      await tester.tap(find.text('次のページ'));
      await tester.pumpAndSettle();
      expect(find.text('夜間保守メモ 2 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing images retain the floor, controls and memo',
      (tester) async {
    await show(tester, bundle: _MissingArt(), reduced: true);
    expect(find.byIcon(Icons.engineering), findsOneWidget);
    await tester.tap(find.text('保守メモを調べる'));
    await tester.pumpAndSettle();
    expect(find.text('夜間保守メモ 1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MissingArt extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Synthetic missing image');
}

class _DelayedWalkArt extends CachingAssetBundle {
  final _pending = Completer<ByteData>();
  bool requested = false;

  void complete(ByteData bytes) => _pending.complete(bytes);
  void fail() =>
      _pending.completeError(StateError('Synthetic walk preload failure'));

  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/echo_pump/character_walk.png') {
      requested = true;
      return _pending.future;
    }
    return rootBundle.load(key);
  }
}
