import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_account_balance_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = AssetAccountBalanceHistoryStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('records a month and reads it back from a later month', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.recordMonth(
      DateTime(2026, 5, 1),
      <String, double>{'famipay': 30000, 'mobit': -200000},
      prefs: prefs,
    );

    final prior = await store.priorMonthBalances(
      DateTime(2026, 6, 1),
      prefs: prefs,
    );

    // 負債残高は絶対値（正の値）で保存される。
    expect(prior['famipay'], 30000);
    expect(prior['mobit'], 200000);
  });

  test('prior month excludes the current month entry', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.recordMonth(
      DateTime(2026, 5, 1),
      <String, double>{'famipay': 30000},
      prefs: prefs,
    );
    await store.recordMonth(
      DateTime(2026, 6, 1),
      <String, double>{'famipay': 100000},
      prefs: prefs,
    );

    final prior = await store.priorMonthBalances(
      DateTime(2026, 6, 1),
      prefs: prefs,
    );

    expect(prior['famipay'], 30000);
  });

  test('returns empty when no prior month exists', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.recordMonth(
      DateTime(2026, 6, 1),
      <String, double>{'famipay': 100000},
      prefs: prefs,
    );

    final prior = await store.priorMonthBalances(
      DateTime(2026, 6, 1),
      prefs: prefs,
    );

    expect(prior, isEmpty);
  });

  test('re-recording the same month overwrites it', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.recordMonth(
      DateTime(2026, 5, 1),
      <String, double>{'famipay': 30000},
      prefs: prefs,
    );
    await store.recordMonth(
      DateTime(2026, 5, 1),
      <String, double>{'famipay': 45000},
      prefs: prefs,
    );

    final prior = await store.priorMonthBalances(
      DateTime(2026, 6, 1),
      prefs: prefs,
    );

    expect(prior['famipay'], 45000);
    expect(await store.recordedMonthKeys(prefs: prefs), <String>['2026-05']);
  });

  test('skips a debt-free (empty) month and returns the last month with debt',
      () async {
    final prefs = await SharedPreferences.getInstance();
    // 4月に借金あり → 5月に完済(空) → 6月に新規借入。
    await store.recordMonth(
      DateTime(2026, 4, 1),
      <String, double>{'famipay': 30000},
      prefs: prefs,
    );
    await store.recordMonth(
      DateTime(2026, 5, 1),
      <String, double>{},
      prefs: prefs,
    );

    final prior = await store.priorMonthBalances(
      DateTime(2026, 6, 1),
      prefs: prefs,
    );

    // 空の5月を飛ばして4月の残高を前月比の基準にする。
    expect(prior['famipay'], 30000);
  });

  test('rejects negative balances on read (corrupted data)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_account_balance_history_v1': jsonEncode(<String, dynamic>{
        '2026-05': <String, dynamic>{'good': 100000, 'bad': -50000},
      }),
    });
    final prefs = await SharedPreferences.getInstance();

    final prior = await store.priorMonthBalances(
      DateTime(2026, 6, 1),
      prefs: prefs,
    );

    expect(prior['good'], 100000);
    expect(prior.containsKey('bad'), isFalse);
  });

  group('mergeRemote (cross-device sync)', () {
    test('adds a remote-only month (union, no data loss)', () async {
      final prefs = await SharedPreferences.getInstance();
      await store.recordMonth(
        DateTime(2026, 6, 1),
        <String, double>{'famipay': 100000},
        prefs: prefs,
      );

      final changed = await store.mergeRemote(
        <String, dynamic>{
          '2026-05': <String, dynamic>{'mobit': 200000},
        },
        prefs: prefs,
      );

      expect(changed, isTrue);
      final all = await store.loadAll(prefs: prefs);
      expect(all['2026-05']!['mobit'], 200000);
      expect(all['2026-06']!['famipay'], 100000);
    });

    test('fills remote-only accounts but keeps local on conflict', () async {
      final prefs = await SharedPreferences.getInstance();
      await store.recordMonth(
        DateTime(2026, 6, 1),
        <String, double>{'famipay': 100000},
        prefs: prefs,
      );

      final changed = await store.mergeRemote(
        <String, dynamic>{
          '2026-06': <String, dynamic>{'famipay': 999999, 'mobit': 50000},
        },
        prefs: prefs,
      );

      expect(changed, isTrue);
      final all = await store.loadAll(prefs: prefs);
      // 共有口座はローカル値を優先、リモート限定口座だけ補完。
      expect(all['2026-06']!['famipay'], 100000);
      expect(all['2026-06']!['mobit'], 50000);
    });

    test('returns false and changes nothing for empty/invalid remote', () async {
      final prefs = await SharedPreferences.getInstance();
      await store.recordMonth(
        DateTime(2026, 6, 1),
        <String, double>{'famipay': 100000},
        prefs: prefs,
      );

      expect(await store.mergeRemote(null, prefs: prefs), isFalse);
      expect(await store.mergeRemote(<String, dynamic>{}, prefs: prefs), isFalse);
      expect(await store.mergeRemote('garbage', prefs: prefs), isFalse);

      final all = await store.loadAll(prefs: prefs);
      expect(all['2026-06']!['famipay'], 100000);
    });

    test('merged remote month becomes the prior-month basis', () async {
      final prefs = await SharedPreferences.getInstance();
      // 今月だけローカルにある状態へ、他端末の先月分をマージ。
      await store.recordMonth(
        DateTime(2026, 6, 1),
        <String, double>{'famipay': 100000},
        prefs: prefs,
      );
      await store.mergeRemote(
        <String, dynamic>{
          '2026-05': <String, dynamic>{'famipay': 30000},
        },
        prefs: prefs,
      );

      final prior = await store.priorMonthBalances(
        DateTime(2026, 6, 1),
        prefs: prefs,
      );
      expect(prior['famipay'], 30000);
    });
  });

  test('prunes history beyond the retention window', () async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < AssetAccountBalanceHistoryStore.maxMonths + 4; i++) {
      final month = DateTime(2025, 1 + i, 1);
      await store.recordMonth(
        month,
        <String, double>{'famipay': 1000.0 * i},
        prefs: prefs,
      );
    }

    final keys = await store.recordedMonthKeys(prefs: prefs);
    expect(keys.length, AssetAccountBalanceHistoryStore.maxMonths);
    // 最古の月から間引かれている。
    expect(keys.first.compareTo(keys.last) < 0, isTrue);
  });
}
