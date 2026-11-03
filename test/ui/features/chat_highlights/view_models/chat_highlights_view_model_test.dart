import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/chat_highlights/data/chat_highlight_export_gateway.dart';
import 'package:my_web_app/ui/features/chat_highlights/data/chat_highlight_gateway.dart';
import 'package:my_web_app/ui/features/chat_highlights/domain/chat_highlight_models.dart';
import 'package:my_web_app/ui/features/chat_highlights/view_models/chat_highlights_view_model.dart';

void main() {
  test('追加時に時系列へ整列・保存し、候補を自動再計算する', () async {
    final gateway = _MemoryGateway();
    final exporter = _MemoryExporter();
    var tick = 0;
    final viewModel = ChatHighlightsViewModel(
      gateway: gateway,
      exportGateway: exporter,
      now: () => DateTime.fromMicrosecondsSinceEpoch(++tick),
    );
    await viewModel.load();
    await viewModel.updateSettings(
      const ChatHighlightSettings(
        minimumComments: 2,
        minimumKeywordEvents: 99,
        keywords: <String>[],
      ),
    );

    await viewModel.addEvent(
      offset: const Duration(seconds: 20),
      author: 'b',
      message: 'second',
    );
    await viewModel.addEvent(
      offset: const Duration(seconds: 10),
      author: 'a',
      message: 'first',
    );

    expect(viewModel.snapshot.events.map((event) => event.message), <String>[
      'first',
      'second',
    ]);
    expect(viewModel.candidates, hasLength(1));
    expect(gateway.saved.events, hasLength(2));
  });

  test('デモ追加を繰り返しても500件上限と再読込後の内容が一致する', () async {
    final gateway = _MemoryGateway();
    final exporter = _MemoryExporter();
    gateway.saved = ChatHighlightSnapshot(
      events: List.generate(
        499,
        (index) => ChatHighlightEvent(
          id: 'existing-$index',
          offset: Duration(seconds: index),
          author: 'viewer',
          message: 'message $index',
        ),
      ),
    );
    final viewModel = ChatHighlightsViewModel(
      gateway: gateway,
      exportGateway: exporter,
    );
    await viewModel.load();
    await viewModel.addDemoEvents();
    await viewModel.addDemoEvents();
    expect(viewModel.snapshot.events, hasLength(500));
    expect(gateway.saved.events, hasLength(500));
    final reloaded = ChatHighlightsViewModel(
      gateway: gateway,
      exportGateway: exporter,
    );
    await reloaded.load();
    expect(
      reloaded.snapshot.events.map((event) => event.id).toList(),
      viewModel.snapshot.events.map((event) => event.id).toList(),
    );
  });

  test('保存失敗後の同じ入力の再試行は同じコメントを保存する', () async {
    final gateway = _FailOnceGateway();
    final viewModel = ChatHighlightsViewModel(
      gateway: gateway,
      exportGateway: _MemoryExporter(),
    );
    await viewModel.load();
    Future<bool> submit() => viewModel.addEvent(
          offset: const Duration(seconds: 10),
          author: 'viewer',
          message: 'コメント',
        );
    expect(await submit(), isFalse);
    expect(viewModel.snapshot.events, hasLength(1));
    expect(await submit(), isTrue);
    expect(gateway.saved.events, hasLength(1));
    expect(await submit(), isTrue);
    expect(gateway.saved.events, hasLength(2));
  });

  test('同時の同一入力は共有し、異なる入力は保持する', () async {
    final gateway = _ControlledGateway();
    final viewModel = ChatHighlightsViewModel(
      gateway: gateway,
      exportGateway: _MemoryExporter(),
    );
    await viewModel.load();
    Future<bool> submit(String message) => viewModel.addEvent(
          offset: const Duration(seconds: 10),
          author: 'viewer',
          message: message,
        );
    final first = submit('first');
    final duplicate = submit('first');
    final second = submit('second');
    expect(viewModel.snapshot.events, hasLength(2));
    gateway.release.complete();
    expect(await Future.wait([first, duplicate, second]), [true, true, true]);
    expect(gateway.saved.events.map((event) => event.message), [
      'first',
      'second',
    ]);
    expect(gateway.saves, 2);
  });

  test('指示書の出力失敗を利用者へ通知する', () async {
    final viewModel = ChatHighlightsViewModel(
      gateway: _MemoryGateway(),
      exportGateway: _FailingExporter(),
    );
    await viewModel.load();
    await viewModel.updateSource(
      title: '配信',
      url: 'https://example.com/video.mp4',
    );
    await viewModel.updateSettings(
      const ChatHighlightSettings(minimumComments: 1),
    );
    await viewModel.addEvent(
      offset: const Duration(seconds: 10),
      author: 'viewer',
      message: '盛り上がり',
    );
    expect(await viewModel.exportManifest(), isFalse);
    expect(viewModel.errorMessage, contains('出力できませんでした'));
  });

  test('有効な動画URLと候補がある場合だけ指示書を出力する', () async {
    final gateway = _MemoryGateway();
    final exporter = _MemoryExporter();
    final viewModel = ChatHighlightsViewModel(
      gateway: gateway,
      exportGateway: exporter,
    );
    await viewModel.load();

    expect(await viewModel.exportManifest(), isFalse);
    await viewModel.updateSource(
      title: '配信',
      url: 'https://example.com/video.mp4',
    );
    await viewModel.updateSettings(
      const ChatHighlightSettings(
        minimumComments: 1,
        minimumKeywordEvents: 99,
        keywords: <String>[],
      ),
    );
    await viewModel.addEvent(
      offset: const Duration(seconds: 10),
      author: 'viewer',
      message: '盛り上がり',
    );

    expect(await viewModel.exportManifest(), isTrue);
    expect(exporter.exports, 1);
  });
}

class _MemoryGateway implements ChatHighlightGateway {
  ChatHighlightSnapshot saved = const ChatHighlightSnapshot();

  @override
  Future<ChatHighlightSnapshot> load() async => saved;

  @override
  Future<void> save(ChatHighlightSnapshot snapshot) async {
    saved = snapshot;
  }
}

class _ControlledGateway implements ChatHighlightGateway {
  final release = Completer<void>();
  ChatHighlightSnapshot saved = const ChatHighlightSnapshot();
  int saves = 0;

  @override
  Future<ChatHighlightSnapshot> load() async => saved;

  @override
  Future<void> save(ChatHighlightSnapshot snapshot) async {
    saves++;
    await release.future;
    saved = snapshot;
  }
}

class _FailOnceGateway implements ChatHighlightGateway {
  ChatHighlightSnapshot saved = const ChatHighlightSnapshot();
  bool fail = true;

  @override
  Future<ChatHighlightSnapshot> load() async => saved;

  @override
  Future<void> save(ChatHighlightSnapshot snapshot) async {
    if (fail) {
      fail = false;
      throw StateError('storage unavailable');
    }
    saved = snapshot;
  }
}

class _FailingExporter implements ChatHighlightExportGateway {
  @override
  Future<void> export({
    required ChatHighlightSnapshot snapshot,
    required List<ChatHighlightCandidate> candidates,
  }) async {
    throw StateError('download unavailable');
  }
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
