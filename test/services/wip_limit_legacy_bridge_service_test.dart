import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/wip_limit_legacy_bridge_service.dart';

void main() {
  test('旧 wip_items を消化キューの互換表示へ変換する', () {
    final items = WipLimitLegacyBridgeService.parseRows(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'wip-1',
        'category': '読書',
        'emoji': '📚',
        'title': '積読を1冊終える',
        'note': '第3章まで',
        'progress_percent': 35,
        'status': 'active',
        'created_at': '2026-08-20T10:00:00Z',
      },
    ]);

    expect(items, hasLength(1));
    expect(items.single.title, '積読を1冊終える');
    expect(items.single.progressPercent, 35);
    expect(items.single.isCompleted, isFalse);
    expect(items.single.createdAt, DateTime.parse('2026-08-20T10:00:00Z'));
  });

  test('欠損値と範囲外進捗を安全に補正する', () {
    final items = WipLimitLegacyBridgeService.parseRows(<Map<String, dynamic>>[
      <String, dynamic>{'progress_percent': 120, 'status': 'completed'},
    ]);

    expect(items.single.title, '名称未設定');
    expect(items.single.category, 'その他');
    expect(items.single.progressPercent, 100);
    expect(items.single.isCompleted, isTrue);
  });

  test('リスト以外は空として扱う', () {
    expect(WipLimitLegacyBridgeService.parseRows(<String, dynamic>{}), isEmpty);
  });
}
