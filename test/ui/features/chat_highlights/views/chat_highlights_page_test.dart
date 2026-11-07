import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/chat_highlights/chat_highlights_feature.dart';
import 'package:my_web_app/ui/features/chat_highlights/data/chat_highlight_export_gateway.dart';
import 'package:my_web_app/ui/features/chat_highlights/data/chat_highlight_gateway.dart';
import 'package:my_web_app/ui/features/chat_highlights/domain/chat_highlight_models.dart';

void main() {
  testWidgets('狭い画面でデモチャットから候補を作り指示書を出力できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _MemoryGateway();
    final exporter = _MemoryExporter();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatHighlightsFeature(
          gateway: gateway,
          exportGateway: exporter,
          now: () => DateTime.utc(2026, 8, 26),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-highlights-narrow')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('chat-highlight-source-url')),
      'https://example.com/video.mp4',
    );
    await tester.ensureVisible(
      find.byKey(const Key('chat-highlight-save-source')),
    );
    await tester.tap(find.byKey(const Key('chat-highlight-save-source')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('chat-highlight-demo')));
    await tester.tap(find.byKey(const Key('chat-highlight-demo')));
    await tester.pumpAndSettle();

    expect(find.text('ハイライト候補 1件'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('chat-highlight-export')));
    await tester.tap(find.byKey(const Key('chat-highlight-export')));
    await tester.pumpAndSettle();
    expect(exporter.exports, 1);
  });

  testWidgets('保存待ち中に入力した次のコメントは消えない', (tester) async {
    final gateway = _DelayedGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHighlightsFeature(
          gateway: gateway,
          exportGateway: _MemoryExporter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final time = find.byKey(const Key('chat-highlight-event-time'));
    final message = find.byKey(const Key('chat-highlight-event-message'));
    final add = find.byKey(const Key('chat-highlight-add-event'));
    await tester.ensureVisible(time);
    await tester.enterText(time, '10');
    await tester.enterText(message, '最初のコメント');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    await tester.enterText(time, '20');
    await tester.enterText(message, '次のコメント');
    gateway.release.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(time).controller!.text, '20');
    expect(tester.widget<TextField>(message).controller!.text, '次のコメント');
  });

  testWidgets('保存失敗時は入力を残してエラーを表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHighlightsFeature(
          gateway: _FailingGateway(),
          exportGateway: _MemoryExporter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final time = find.byKey(const Key('chat-highlight-event-time'));
    final message = find.byKey(const Key('chat-highlight-event-message'));
    final add = find.byKey(const Key('chat-highlight-add-event'));
    await tester.ensureVisible(time);
    await tester.enterText(time, '10');
    await tester.enterText(message, '保持するコメント');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(message).controller!.text, '保持するコメント');
    expect(find.textContaining('保存できませんでした'), findsOneWidget);
  });

  testWidgets('広い画面では設定と結果を2カラム表示する', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatHighlightsFeature(
          gateway: _MemoryGateway(),
          exportGateway: _MemoryExporter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-highlights-wide')), findsOneWidget);
  });
}

class _MemoryGateway implements ChatHighlightGateway {
  ChatHighlightSnapshot snapshot = const ChatHighlightSnapshot();

  @override
  Future<ChatHighlightSnapshot> load() async => snapshot;

  @override
  Future<void> save(ChatHighlightSnapshot value) async {
    snapshot = value;
  }
}

class _FailingGateway implements ChatHighlightGateway {
  @override
  Future<ChatHighlightSnapshot> load() async => const ChatHighlightSnapshot();

  @override
  Future<void> save(ChatHighlightSnapshot value) async {
    throw StateError('storage unavailable');
  }
}

class _DelayedGateway implements ChatHighlightGateway {
  final release = Completer<void>();

  @override
  Future<ChatHighlightSnapshot> load() async => const ChatHighlightSnapshot();

  @override
  Future<void> save(ChatHighlightSnapshot value) => release.future;
}

class _MemoryExporter implements ChatHighlightExportGateway {
  int exports = 0;

  @override
  Future<void> export({
    required ChatHighlightSnapshot snapshot,
    required List<ChatHighlightCandidate> candidates,
  }) async {
    exports++;
  }
}
