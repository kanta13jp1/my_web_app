import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_sync_timestamp_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetSyncTimestampStore', () {
    const store = AssetSyncTimestampStore();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('returns null when no timestamp stored', () async {
      expect(await store.loadTimestamp('watchlist_entries'), isNull);
    });

    test('marks and reads back a per-key timestamp', () async {
      final at = DateTime.utc(2026, 6, 14, 9, 30);
      await store.markChanged('main_account_id', at: at);
      expect(await store.loadTimestamp('main_account_id'), at);
      // 別キーは独立。
      expect(await store.loadTimestamp('watchlist_entries'), isNull);
    });

    test('keeps multiple keys independently and overwrites in place', () async {
      final a = DateTime.utc(2026, 6, 14, 9, 0);
      final b = DateTime.utc(2026, 6, 14, 10, 0);
      final c = DateTime.utc(2026, 6, 14, 11, 0);
      await store.markChanged('main_account_id', at: a);
      await store.markChanged('watchlist_entries', at: b);
      await store.markChanged('main_account_id', at: c);

      expect(await store.loadTimestamp('main_account_id'), c);
      expect(await store.loadTimestamp('watchlist_entries'), b);
      expect((await store.loadAll()).length, 2);
    });
  });
}
