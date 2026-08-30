import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_alert_dismissal_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = AssetAlertDismissalStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load returns empty set when nothing stored', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(await store.load(prefs: prefs), isEmpty);
  });

  test('dismiss persists and load returns the id', () async {
    final prefs = await SharedPreferences.getInstance();
    final next = await store.dismiss('overdue:acc:2026-05-15', prefs: prefs);
    expect(next, contains('overdue:acc:2026-05-15'));
    expect(await store.load(prefs: prefs), contains('overdue:acc:2026-05-15'));
  });

  test('dismiss is idempotent and ignores blank ids', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.dismiss('a', prefs: prefs);
    final again = await store.dismiss('a', prefs: prefs);
    expect(again, {'a'});
    final blank = await store.dismiss('   ', prefs: prefs);
    expect(blank, {'a'});
  });

  test('restore removes a dismissed id', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.dismiss('a', prefs: prefs);
    await store.dismiss('b', prefs: prefs);
    final next = await store.restore('a', prefs: prefs);
    expect(next, {'b'});
  });

  test('prune keeps only live ids', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.dismiss('a', prefs: prefs);
    await store.dismiss('b', prefs: prefs);
    await store.dismiss('c', prefs: prefs);
    final next = await store.prune({'b', 'c', 'x'}, prefs: prefs);
    expect(next, {'b', 'c'});
    expect(await store.load(prefs: prefs), {'b', 'c'});
  });
}
