import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_card_usage_policy_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = AssetCardUsagePolicyStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'persists and restores the completion timestamp and audit memo',
    () async {
      final changedAt = DateTime.utc(2026, 8, 29, 6, 18);
      await store.save(<String, AssetCardUsagePolicy>{
        'famipay_card': AssetCardUsagePolicy(
          enforceOneShot: true,
          changedAt: changedAt,
          memo: '受付 ABC123 / 8月29日 電話',
        ),
      });

      final restored = await store.load();

      expect(restored.keys, contains('famipay_card'));
      expect(restored['famipay_card']!.enforceOneShot, isTrue);
      expect(restored['famipay_card']!.changedAt, changedAt);
      expect(restored['famipay_card']!.memo, '受付 ABC123 / 8月29日 電話');
    },
  );

  test('decodes snake_case mirror values and ignores malformed entries', () {
    final restored = AssetCardUsagePolicyStore.decodeMirrorValue(
      <String, dynamic>{
        'famipay_card': <String, dynamic>{
          'enforce_one_shot': true,
          'changed_at': '2026-08-29T06:18:55.608Z',
          'memo': '受付 9876',
        },
        '': <String, dynamic>{'enforce_one_shot': true},
        'broken': 'not-an-object',
      },
    );

    expect(restored, hasLength(1));
    expect(restored['famipay_card']!.enforceOneShot, isTrue);
    expect(restored['famipay_card']!.changedAt, isNotNull);
    expect(restored['famipay_card']!.memo, '受付 9876');
  });
}
