import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/controllers/note_version_history_controller.dart';
import 'package:my_web_app/services/note_version_history_service.dart';

NoteVersionSummary summary(int number) => NoteVersionSummary(
      cursor: NoteVersionCursor(
        id: '22222222-2222-4222-8222-${number.toString().padLeft(12, '0')}',
        savedAt: '2026-09-12T00:00:00Z',
      ),
      title: 'History $number',
      sourceSystem: 'native',
      sourceVerified: false,
    );

class _Repository implements NoteVersionHistoryRepository {
  final cursors = <NoteVersionCursor?>[];
  final details = <String, Completer<NoteVersionDetail>>{};
  late Future<NoteVersionPage> Function() nextPage;

  @override
  Future<NoteVersionPage> loadPage(String noteId, {NoteVersionCursor? before}) {
    cursors.add(before);
    return nextPage();
  }

  @override
  Future<NoteVersionDetail> loadDetail(String noteId, String versionId) =>
      details.putIfAbsent(versionId, Completer<NoteVersionDetail>.new).future;
}

void main() {
  late _Repository repository;
  late NoteVersionHistoryController controller;

  setUp(() {
    repository = _Repository();
    controller = NoteVersionHistoryController(repository: repository, noteId: '42');
  });
  tearDown(() => controller.dispose());

  test('31st and older revisions remain reachable with no duplicate entries',
      () async {
    repository.nextPage = () async => NoteVersionPage(
          items: List.generate(30, summary),
          hasMore: true,
        );
    await controller.loadMore();
    repository.nextPage = () async => NoteVersionPage(
          items: [summary(29), summary(30), summary(31)],
          hasMore: false,
        );
    await controller.loadMore();
    expect(controller.items, hasLength(32));
    expect(repository.cursors.last?.id, summary(29).id);
    expect(controller.items.last.id, summary(31).id);
    expect(controller.hasMore, isFalse);
    await controller.loadMore();
    expect(repository.cursors, hasLength(2));
    expect(repository.details, isEmpty);
  });

  test('failed later page keeps loaded items and retries same cursor', () async {
    repository.nextPage = () async =>
        NoteVersionPage(items: [summary(1)], hasMore: true);
    await controller.loadMore();
    repository.nextPage = () async => throw StateError('private error payload');
    await controller.loadMore();
    expect(controller.items.single.id, summary(1).id);
    expect(controller.pageError, isNot(contains('private error payload')));
    repository.nextPage = () async =>
        NoteVersionPage(items: [summary(2)], hasMore: false);
    await controller.loadMore();
    expect(repository.cursors[1]?.id, repository.cursors[2]?.id);
    expect(controller.pageError, isNull);
    expect(controller.items, hasLength(2));
  });

  test('duplicate load clicks share one pending page request', () async {
    final gate = Completer<NoteVersionPage>();
    repository.nextPage = () => gate.future;
    final first = controller.loadMore();
    await controller.loadMore();
    expect(repository.cursors, hasLength(1));
    gate.complete(NoteVersionPage(items: [], hasMore: false));
    await first;
  });

  test('stale preview response cannot overwrite a later selection', () async {
    final first = controller.select(summary(1));
    final second = controller.select(summary(2));
    repository.details[summary(2).id]!.complete(
      NoteVersionDetail(summary: summary(2), content: 'second'),
    );
    await second;
    repository.details[summary(1).id]!.complete(
      NoteVersionDetail(summary: summary(1), content: 'first'),
    );
    await first;
    expect(controller.detail?.content, 'second');
  });

  test('back invalidates pending preview and frees selected body', () async {
    final pending = controller.select(summary(1));
    controller.showList();
    repository.details[summary(1).id]!.complete(
      NoteVersionDetail(summary: summary(1), content: 'old private body'),
    );
    await pending;
    expect(controller.selected, isNull);
    expect(controller.detail, isNull);
    expect(controller.detailLoading, isFalse);
  });

  test('detail failure remains retryable and does not expose raw errors',
      () async {
    final pending = controller.select(summary(1));
    repository.details[summary(1).id]!.completeError(
      StateError('private signed URL'),
    );
    await pending;
    expect(controller.detail, isNull);
    expect(controller.detailError, isNot(contains('private signed URL')));
    repository.details.remove(summary(1).id);
    final retry = controller.select(summary(1));
    repository.details[summary(1).id]!.complete(
      NoteVersionDetail(summary: summary(1), content: 'recovered'),
    );
    await retry;
    expect(controller.detail?.content, 'recovered');
  });

  test('non-advancing page is an error rather than an infinite load loop',
      () async {
    repository.nextPage = () async =>
        NoteVersionPage(items: [summary(1)], hasMore: true);
    await controller.loadMore();
    await controller.loadMore();
    expect(controller.pageError, isNotNull);
    expect(controller.items, hasLength(1));
  });

  test('disposal ignores an outstanding request', () async {
    final other = NoteVersionHistoryController(repository: repository, noteId: '42');
    final gate = Completer<NoteVersionPage>();
    repository.nextPage = () => gate.future;
    final pending = other.loadMore();
    other.dispose();
    gate.complete(NoteVersionPage(items: [summary(1)], hasMore: false));
    await pending;
    expect(other.items, isEmpty);
  });
}
