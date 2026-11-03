import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payment_day_owner_store_candidate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AssetPaymentDayOwnerStoreCandidate.resetForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('pending snapshot survives later edits and simulated process restart', () async {
    final prefs = await SharedPreferences.getInstance();
    var session = Object();
    var store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await store.edit('a', 'debt-x', 10);
    await store.edit('a', 'debt-y', null);
    final sent = (await store.begin('a'))!;
    final sentSequence = sent.sequence;
    final sentNonce = sent.nonce;
    await store.edit('a', 'debt-x', 11);
    await store.edit('a', 'debt-y', 12);
    // Simulate process statics and auth generation being replaced. The mock
    // preferences deliberately survive; this is not a real browser restart.
    AssetPaymentDayOwnerStoreCandidate.resetForTest();
    session = Object();
    store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    final restored = await store.inspect('a');
    final pending = Map<String, dynamic>.from(restored['pending'] as Map);
    expect(pending['sequence'], sentSequence);
    expect(pending['nonce'], sentNonce);
    expect(restored['values'], {'debt-x': 11, 'debt-y': 12});
    expect(restored['dirty'], isTrue);
    expect(
      {'values': pending['values'], 'deleted': pending['deleted']},
      {'values': {'debt-x': 10}, 'deleted': ['debt-y']},
      reason: 'A must preserve both original values and tombstones for replay',
    );
  });

  test('legacy pending without original payload fails closed without overwrite', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw = '{"version":1,"owners":{"a":{"revision":1,"sequence":1,"values":{"x":11},"deleted":[],"dirty":true,"pending":{"sequence":1,"revision":1,"nonce":"0123456789abcdef0123456789abcdef"}}}}';
    await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, raw);
    final session = Object();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(store.inspect('a'), throwsFormatException);
    expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), raw);
  });

  test('invalid pending payload fails closed without overwrite', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw = '{"version":1,"owners":{"a":{"revision":1,"sequence":1,"values":{"x":11},"deleted":[],"dirty":true,"pending":{"sequence":1,"revision":1,"nonce":"0123456789abcdef0123456789abcdef","values":{"x":10},"deleted":["x"]}}}}';
    await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, raw);
    final session = Object();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(store.inspect('a'), throwsFormatException);
    expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), raw);
  });


  test('same revision with different pending payload fails closed', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw = '{"version":1,"owners":{"a":{"revision":1,"sequence":1,"values":{"x":11},"deleted":[],"dirty":true,"pending":{"sequence":1,"revision":1,"nonce":"0123456789abcdef0123456789abcdef","values":{"x":10},"deleted":[]}}}}';
    await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, raw);
    final session = Object();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(store.inspect('a'), throwsFormatException);
    expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), raw);
  });


  test('old ticket cannot acknowledge an altered pending payload', () async {
    final prefs = await SharedPreferences.getInstance();
    final session = Object();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await store.edit('a', 'x', 10);
    final ticket = (await store.begin('a'))!;
    await store.edit('a', 'x', 11);
    final root = jsonDecode(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey)!) as Map<String, dynamic>;
    final owner = (root['owners'] as Map<String, dynamic>)['a'] as Map<String, dynamic>;
    final pending = owner['pending'] as Map<String, dynamic>;
    (pending['values'] as Map<String, dynamic>)['x'] = 9;
    final altered = jsonEncode(root);
    await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, altered);
    await expectLater(store.acknowledgeConfirmed(ticket), throwsStateError);
    expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), altered);
    expect((await store.inspect('a'))['dirty'], isTrue);
  });


  test('non-integer pending sequence is rejected without overwrite', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw = '{"version":1,"owners":{"a":{"revision":1,"sequence":1,"values":{"x":10},"deleted":[],"dirty":true,"pending":{"sequence":1.0,"revision":1,"nonce":"0123456789abcdef0123456789abcdef","values":{"x":10},"deleted":[]}}}}';
    await prefs.setString(AssetPaymentDayOwnerStoreCandidate.storageKey, raw);
    final session = Object();
    final store = AssetPaymentDayOwnerStoreCandidate(prefs, (owner) => owner == 'a', () => session);
    await expectLater(store.inspect('a'), throwsFormatException);
    expect(prefs.getString(AssetPaymentDayOwnerStoreCandidate.storageKey), raw);
  });

}
