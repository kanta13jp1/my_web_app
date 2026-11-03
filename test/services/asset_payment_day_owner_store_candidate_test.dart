import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payment_day_owner_store_candidate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Object session;
  setUp(() {
    session = Object();
    AssetPaymentDayOwnerStoreCandidate.resetForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('old acknowledgement preserves the later owner edit', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await store.edit('a', 'debt', 10);
    final a = (await store.begin('a'))!;
    await store.edit('a', 'debt', 11);
    await store.acknowledgeConfirmed(a);
    final interim = await store.inspect('a');
    expect(interim['dirty'], isTrue);
    expect(interim['values'], {'debt': 11});
    final b = (await store.begin('a'))!;
    expect(b.values, {'debt': 11});
    await store.acknowledgeConfirmed(b);
    expect((await store.inspect('a'))['dirty'], isFalse);
  });

  test('same-value edit has a new revision and cannot be acknowledged by A', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await store.edit('a', 'debt', 10);
    final first = (await store.begin('a'))!;
    await store.edit('a', 'debt', 10);
    await store.acknowledgeConfirmed(first);
    expect((await store.inspect('a'))['dirty'], isTrue);
  });

  test('owner switch cannot send or clear the other owner state', () async {
    final prefs = await SharedPreferences.getInstance();
    var current = 'a';
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == current, () => session);
    await store.edit('a', 'debt', 10);
    final ticket = (await store.begin('a'))!;
    current = 'b';
    session = Object();
    await expectLater(store.acknowledgeConfirmed(ticket), throwsStateError);
    expect((await store.inspect('b'))['values'], isEmpty);
    await store.edit('b', 'other', 12);
    current = 'a';
    session = Object();
    await expectLater(store.acknowledgeConfirmed(ticket), throwsStateError);
    final a = await store.inspect('a');
    expect(a['values'], {'debt': 10});
    expect(a['pending'], isNotNull);
    expect(a['dirty'], isTrue);
  });

  test('delete then reset is retained while the old write is pending', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await store.edit('a', 'debt', null);
    final deletion = (await store.begin('a'))!;
    expect(deletion.deleted, ['debt']);
    await store.edit('a', 'debt', 12);
    await store.acknowledgeConfirmed(deletion);
    final state = await store.inspect('a');
    expect(state['dirty'], isTrue);
    expect(state['values'], {'debt': 12});
    expect(state['deleted'], isEmpty);
    final next = (await store.begin('a'))!;
    expect(next.values, {'debt': 12});
    expect(next.deleted, isEmpty);
  });

  test('unresolved marker survives replacing the store instance', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await first.edit('a', 'debt', 10);
    await first.begin('a');
    final second = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(second.begin('a'), throwsStateError);
    expect((await second.inspect('a'))['pending'], isNotNull);
  });

  test('corrupt persisted data is not replaced with an empty state', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, '{broken');
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(store.edit('a', 'debt', 10), throwsFormatException);
    expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), '{broken');
  });

  test('missing pending field and null owner never become a clean state', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    for (final raw in <String>[
      '{"version":1,"owners":{"a":null}}',
      '{"version":1,"owners":{"a":{"revision":1,"sequence":1,"values":{"x":10},"deleted":[],"dirty":true}}}',
    ]) {
      await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, raw);
      await expectLater(store.begin('a'), throwsFormatException);
      expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), raw);
    }
  });

  test('old ticket cannot acknowledge a new state after sequence reuse', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await store.edit('a', 'debt', 10);
    final old = (await store.begin('a'))!;
    // Simulate rollback/reset of the synthetic storage only.
    await prefs.remove(AssetPaymentDayOwnerStoreCandidate.storageKey);
    await store.edit('a', 'other', 11);
    final newer = (await store.begin('a'))!;
    expect(old.sequence, newer.sequence);
    expect(old.revision, newer.revision);
    expect(old.nonce, isNot(newer.nonce));
    await expectLater(store.acknowledgeConfirmed(old), throwsStateError);
    final state = await store.inspect('a');
    expect(state['pending'], isNotNull);
    expect(state['values'], {'other': 11});
  });

  test('duplicate pending JSON fails closed without overwriting data', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw = '{"version":1,"owners":{"a":{"revision":1,"sequence":1,"values":{"x":10},"deleted":[],"dirty":true,"pending":{"sequence":1,"revision":1,"nonce":"0123456789abcdef0123456789abcdef"},"pending":null}}}';
    await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, raw);
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(store.begin('a'), throwsFormatException);
    expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), raw);
  });

  test('ambiguous local write blocks another instance in this isolate', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session,
      testWrite: (key, value) async {
        await prefs.setString(key, value);
        throw StateError('synthetic response lost after write');
      });
    await expectLater(store.edit('a', 'debt', 10), throwsStateError);
    final second = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(second.begin('a'), throwsStateError);
  });
}
