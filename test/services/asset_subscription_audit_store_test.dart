import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_subscription_audit_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime utc(int y, int m, int d) => DateTime.utc(y, m, d);

  group('AssetSubscriptionAuditStore encode/decode', () {
    test('round-trips state and normalizes to UTC', () {
      final state = <String, DateTime>{
        'apple_id': utc(2026, 6, 1),
        'card_aupay_card': utc(2026, 5, 20),
      };
      final encoded = AssetSubscriptionAuditStore.encodeMirrorValue(state);
      expect(encoded['apple_id'], '2026-06-01T00:00:00.000Z');
      final decoded = AssetSubscriptionAuditStore.decodeMirrorValue(encoded);
      expect(decoded['apple_id'], utc(2026, 6, 1));
      expect(decoded['apple_id']!.isUtc, isTrue);
      expect(decoded['card_aupay_card'], utc(2026, 5, 20));
    });

    test('decode drops non-string keys, blank keys and unparseable dates', () {
      expect(AssetSubscriptionAuditStore.decodeMirrorValue(null), isEmpty);
      expect(
        AssetSubscriptionAuditStore.decodeMirrorValue('not a map'),
        isEmpty,
      );
      final decoded = AssetSubscriptionAuditStore.decodeMirrorValue(
        <dynamic, dynamic>{
          'apple_id': '2026-06-01T00:00:00.000Z',
          '  ': '2026-06-01T00:00:00.000Z',
          'bad_date': 'not-a-date',
          'au_kantan': 12345,
        },
      );
      expect(decoded.keys, <String>{'apple_id'});
    });

    test('encode skips blank source ids', () {
      final encoded = AssetSubscriptionAuditStore.encodeMirrorValue(
        <String, DateTime>{
          ' ': utc(2026, 6, 1),
          'google_play': utc(2026, 6, 1),
        },
      );
      expect(encoded.keys, <String>{'google_play'});
    });
  });

  group('AssetSubscriptionAuditStore.mergeMax', () {
    test('takes the later timestamp per source (both argument orders)', () {
      final local = <String, DateTime>{'apple_id': utc(2026, 5, 1)};
      final server = <String, DateTime>{'apple_id': utc(2026, 6, 1)};
      expect(
        AssetSubscriptionAuditStore.mergeMax(local, server)['apple_id'],
        utc(2026, 6, 1),
      );
      // 逆順でも同じ結果 (順序非依存)。
      expect(
        AssetSubscriptionAuditStore.mergeMax(server, local)['apple_id'],
        utc(2026, 6, 1),
      );
    });

    test('unions disjoint keys', () {
      final merged = AssetSubscriptionAuditStore.mergeMax(
        <String, DateTime>{'apple_id': utc(2026, 6, 1)},
        <String, DateTime>{'au_kantan': utc(2026, 6, 2)},
      );
      expect(merged.keys, <String>{'apple_id', 'au_kantan'});
    });

    test('empty is an identity element', () {
      final state = <String, DateTime>{'apple_id': utc(2026, 6, 1)};
      expect(
        AssetSubscriptionAuditStore.mergeMax(state, const <String, DateTime>{}),
        state,
      );
      expect(
        AssetSubscriptionAuditStore.mergeMax(const <String, DateTime>{}, state),
        state,
      );
    });
  });

  group('AssetSubscriptionAuditStore persistence', () {
    const store = AssetSubscriptionAuditStore();

    test('save/load round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        <String, DateTime>{'apple_id': utc(2026, 6, 1)},
        prefs: prefs,
      );
      final loaded = await store.load(prefs: prefs);
      expect(loaded['apple_id'], utc(2026, 6, 1));
    });

    test('save empty clears the key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        <String, DateTime>{'apple_id': utc(2026, 6, 1)},
        prefs: prefs,
      );
      await store.save(const <String, DateTime>{}, prefs: prefs);
      expect(await store.load(prefs: prefs), isEmpty);
    });

    test('load returns empty when nothing stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      expect(await store.load(prefs: prefs), isEmpty);
    });
  });
}
