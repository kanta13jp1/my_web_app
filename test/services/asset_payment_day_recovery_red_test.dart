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
}
