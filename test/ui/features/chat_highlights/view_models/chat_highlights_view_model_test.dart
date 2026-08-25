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
