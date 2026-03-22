import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/digest_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('queues second item in same domain while first item is active', () async {
    var tick = 0;
    final service = DigestQueueService(
      nowProvider: () => DateTime(2026, 3, 23, 8, 0, tick++),
    );

    final first = await service.addItem(
      title: '国家とは何か',
      domain: '読書',
    );
    final second = await service.addItem(
      title: '政治学の教科書',
      domain: '読書',
    );

    expect(first.item.status, DigestItemStatus.active);
    expect(second.item.status, DigestItemStatus.backlog);
    expect(second.queued, isTrue);
  });

  test('completing active item promotes next backlog item', () async {
    var tick = 0;
    final service = DigestQueueService(
      nowProvider: () => DateTime(2026, 3, 23, 9, 0, tick++),
    );

    final first = await service.addItem(
      title: '積読1冊目',
      domain: '読書',
    );
    await service.addItem(
      title: '積読2冊目',
      domain: '読書',
    );

    final items = await service.completeItem(
      first.item.id,
      note: '要点を3つ書き出した',
    );

    final nextActive = DigestQueueService.findActiveForDomain(items, '読書');
    final completed = items.firstWhere((item) => item.id == first.item.id);

    expect(completed.status, DigestItemStatus.completed);
    expect(completed.progressEntries.last.note, '要点を3つ書き出した');
    expect(nextActive?.title, '積読2冊目');
    expect(nextActive?.status, DigestItemStatus.active);
  });

  test('recording progress persists latest digestion note', () async {
    var tick = 0;
    final service = DigestQueueService(
      nowProvider: () => DateTime(2026, 3, 23, 10, 0, tick++),
    );

    final created = await service.addItem(
      title: '経済学の講義',
      domain: '講座',
    );

    await service.recordProgress(
      created.item.id,
      '第1回を見て、需要と供給をノートに整理した',
    );

    final loaded = await service.loadItems();
    final item = loaded.firstWhere((entry) => entry.id == created.item.id);

    expect(item.progressEntries, hasLength(1));
    expect(
      item.latestProgress?.note,
      '第1回を見て、需要と供給をノートに整理した',
    );
  });
}
