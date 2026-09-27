import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_chat.dart';
import 'package:my_web_app/pages/chat_replay_page.dart';

AssetChatStoredMessage message(String text) => AssetChatStoredMessage(
      id: text,
      threadId: 'synthetic',
      role: AssetChatMessageRole.user,
      text: text,
      tokensIn: 0,
      tokensOut: 0,
      model: null,
      createdAt: DateTime.utc(2026),
    );

void main() {
  testWidgets('freezes input, conceals content, clamps and rewinds', (tester) async {
    final source = [message('一件目'), message('二件目')];
    final page = ChatReplayPage(messages: source);
    source.clear();
    await tester.pumpWidget(MaterialApp(home: page));
    expect(find.text('一件目'), findsNothing);
    expect(find.text('0 / 2 件'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('一件目'), findsOneWidget);
    expect(find.text('二件目'), findsNothing);
    await tester.tap(find.text('次へ'));
    await tester.pump();
    expect(find.text('二件目'), findsOneWidget);
    expect(find.text('一件目'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('2 / 2 件'), findsOneWidget);
    await tester.tap(find.text('前へ'));
    await tester.pump();
    expect(find.text('一件目'), findsOneWidget);
    await tester.tap(find.text('最初に戻す'));
    await tester.pump();
    expect(find.text('一件目'), findsNothing);
    expect(find.text('0 / 2 件'), findsOneWidget);
  });

  testWidgets('empty snapshot has no next action', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ChatReplayPage(messages: [])));
    expect(find.text('再生する会話がありません'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('0 / 0 件'), findsOneWidget);
  });

  testWidgets('partial long content scrolls at narrow width and double text size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: ChatReplayPage(messages: [message('長い本文\n' * 80)], hasOlderMessages: true),
    ));
    expect(find.byKey(const Key('chat_replay_partial')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(find.text('0 / 1 件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
