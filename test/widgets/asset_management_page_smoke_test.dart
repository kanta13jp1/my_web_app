import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_expected_inflow_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:my_web_app/services/asset_management_main_account_store.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
import 'package:my_web_app/services/asset_sync_timestamp_store.dart';
import 'package:my_web_app/services/asset_watchlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 支払日上書きだけ差し替え可能なテスト用 repo (#part295 fake repo 足場)。
/// 他のロード/保存は SharedPreferences 実装に委譲(テストでは空)。
class _FakeDebtOverrideRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _FakeDebtOverrideRepository(this._seed);

  final Map<String, int> _seed;
  Map<String, int>? savedDebtOverrides;

  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async {
    return Map<String, int>.from(_seed);
  }

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) async {
    savedDebtOverrides = Map<String, int>.from(overrides);
  }
}

/// 資産管理ページの widget スモーク足場 (#3260)。
/// 未ログイン (auth.currentUser == null) では Supabase フェッチ群が
/// 早期 return する性質を利用し、ネットワークなしで UI 契約だけを検証する。
Future<void> _pumpAssetPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: AssetManagementPage()),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AssetManagementPage smoke', () {
    testWidgets('display mode chips reduce visible sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      expect(find.byKey(const Key('asset_display_mode_minimum')), findsOne);
      final cardsInFull = tester.widgetList(find.byType(Card)).length;

      await tester.tap(find.byKey(const Key('asset_display_mode_minimum')));
      await tester.pump(const Duration(milliseconds: 100));

      final cardsInMinimum = tester.widgetList(find.byType(Card)).length;
      expect(cardsInMinimum, lessThan(cardsInFull));
      expect(find.textContaining('最重要のみ'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets('calendar month navigation updates the label', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      final now = DateTime.now();
      final current = DateFormat('yyyy年M月').format(now);
      final next = DateFormat(
        'yyyy年M月',
      ).format(DateTime(now.year, now.month + 1));
      expect(find.text(current), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_next_month')),
      );
      await tester.tap(find.byKey(const Key('asset_calendar_next_month')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(next), findsOneWidget);
      expect(find.text(current), findsNothing);

      await _unmount(tester);
    });

    testWidgets('tapping a day reveals the prefill action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      expect(
        find.byKey(const Key('asset_calendar_prefill_flow_button')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_day_15')),
      );
      await tester.tap(find.byKey(const Key('asset_calendar_day_15')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('asset_calendar_prefill_flow_button')),
        findsOneWidget,
      );

      await _unmount(tester);
    });

    testWidgets('starts in stored minimum mode', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1': 'minimum',
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('最重要のみ'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets('seeded inflows surface as chips and managed rules', (
      tester,
    ) async {
      final now = DateTime.now();
      final monthKey = '${now.year}${now.month.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflows_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_one',
            'date': DateTime(now.year, now.month, 10).toUtc().toIso8601String(),
            'amount': 5000,
            'label': '臨時収入',
          },
        ]),
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_rule',
            'day_of_month': 25,
            'amount': 280000,
            'label': '給料',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_chip_seeded_one')),
      );
      expect(
        find.byKey(const Key('asset_inflow_chip_seeded_one')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('asset_inflow_chip_rule_seeded_rule_$monthKey')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_rules_button')),
      );
      await tester.tap(find.byKey(const Key('asset_inflow_rules_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('毎月25日 給料'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('tombstone GC settings dialog edits and saves the config', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_rule',
            'day_of_month': 25,
            'amount': 280000,
            'label': '給料',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugTombstoneGcConfig: AssetTombstoneGcConfig(
              maxCount: 1000,
              maxAgeDays: 365,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_rules_button')),
      );
      await tester.tap(find.byKey(const Key('asset_inflow_rules_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // 現在値が保持設定ボタンに出ている。
      expect(find.textContaining('保持設定 (1000件/365日)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('asset_tombstone_gc_edit')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const Key('asset_tombstone_gc_maxcount')),
        '50',
      );
      await tester.enterText(
        find.byKey(const Key('asset_tombstone_gc_maxage')),
        '90',
      );
      await tester.tap(find.byKey(const Key('asset_tombstone_gc_save')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // SnackBar で更新を通知し、ボタンラベルも新値へ更新される。
      expect(find.textContaining('最大50件 / 90日'), findsOneWidget);
      expect(find.textContaining('保持設定 (50件/90日)'), findsOneWidget);

      // ローカルにも保存される。
      expect(
        (await AssetExpectedInflowStore.loadGcConfig()).maxCount,
        50,
      );

      await _unmount(tester);
    });

    testWidgets('manual prune button cleans expired tombstones', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_rule',
            'day_of_month': 25,
            'amount': 280000,
            'label': '給料',
          },
        ]),
        // 2020 年の古い削除記録 → inflow は maxAgeDays:10、override は既定365日で
        // どちらも期限切れ → 一括掃除で 2 件 (#part292)。
        'asset_expected_inflow_deleted_ids_v1':
            jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'old1', 'at': '2020-01-01T00:00:00.000Z'},
        ]),
        'asset_management_section_override_deleted_v1':
            jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'chart', 'at': '2020-01-01T00:00:00.000Z'},
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugTombstoneGcConfig: AssetTombstoneGcConfig(
              maxCount: 1000,
              maxAgeDays: 10,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_rules_button')),
      );
      await tester.tap(find.byKey(const Key('asset_inflow_rules_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('asset_tombstone_gc_edit')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('asset_tombstone_gc_prune')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // ボタン→prune→SnackBar の配線を検証 (件数は boot 自動 prune が先に
      // 期限切れを掃除するため非依存にする / #part296)。実際の物理削除は
      // 「boot auto-prune」テストと store 単体テストで担保。
      expect(find.textContaining('件 掃除しました'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('boot auto-prune physically drops expired tombstones', (
      tester,
    ) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        // 期限切れ(2020) + 期限内(現在) を混在させる。
        'asset_expected_inflow_deleted_ids_v1':
            jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'old1', 'at': '2020-01-01T00:00:00.000Z'},
          <String, String>{
            'id': 'recent',
            'at': now.toUtc().toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // boot 自動 prune が期限切れ(old1)を物理削除し、期限内(recent)は残す。
      final raw = (await SharedPreferences.getInstance())
          .getString('asset_expected_inflow_deleted_ids_v1');
      expect(raw, isNotNull);
      expect(raw!.contains('old1'), isFalse);
      expect(raw.contains('recent'), isTrue);

      await _unmount(tester);
    });

    testWidgets('remote section-override tombstone removes local override', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_section_overrides_v1': jsonEncode(
          <String, String>{'chart': 'hidden'},
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末で chart の上書きを削除した状態をミラー注入。
      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugSectionOverrideDeletedMirror: <String, dynamic>{
              'ids': <String>['chart'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // カスタマイズダイアログを開き、chart の上書きが「自動」に戻ったことを確認。
      await tester.ensureVisible(
        find.byKey(const Key('asset_section_customize_button')),
      );
      await tester.tap(find.byKey(const Key('asset_section_customize_button')));
      await tester.pump(const Duration(milliseconds: 200));

      final dropdown = tester
          .widget<DropdownButton<AssetManagementSectionVisibilityOverride>>(
        find.byKey(const Key('asset_section_override_chart')),
      );
      expect(dropdown.value, AssetManagementSectionVisibilityOverride.auto);

      await _unmount(tester);
    });

    testWidgets('remote debt-override tombstone removes it via fake repo', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // fake repo が debt_1/debt_2 の支払日上書きを返す。他端末が debt_1 を削除した
      // 状態をミラー注入 → boot pull + ロード除外で debt_1 が消え、repo へ保存される。
      final repo = _FakeDebtOverrideRepository(<String, int>{
        'debt_1': 27,
        'debt_2': 5,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            assetLiabilityRepository: repo,
            debugDebtOverrideDeletedMirror: const <String, dynamic>{
              'ids': <String>['debt_1'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 削除伝播の結果が repo へ保存される(debt_1 除外 / debt_2 維持)。
      expect(repo.savedDebtOverrides, isNotNull);
      expect(repo.savedDebtOverrides!.containsKey('debt_1'), isFalse);
      expect(repo.savedDebtOverrides!['debt_2'], 5);

      await _unmount(tester);
    });

    testWidgets('revolving config syncs from server mirror on a fresh device', (
      tester,
    ) async {
      // 端末A が保存したリボ設定を集約ミラー値へエンコードする(端末A の upload 相当)。
      final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            creditLimit: 500000,
          ),
        },
      );

      // 端末B はローカル空(別ブラウザ/別ログイン)で起動する。
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror: mirrorValue,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 起動時にミラーから復元され、端末B のローカルにも書き戻される。
      final synced = await const AssetRevolvingCreditConfigStore().load();
      expect(synced.keys, contains('aupay'));
      expect(synced['aupay']!.monthlyAmount, 10000);
      expect(synced['aupay']!.creditLimit, 500000);

      await _unmount(tester);
    });

    testWidgets('local revolving config is not clobbered by the mirror', (
      tester,
    ) async {
      // 端末B が既にローカル設定を持つ場合、ミラーは上書きしない(安全側)。
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
          AssetRevolvingCreditConfigStore.encodeMirrorValue(
            <String, AssetLiabilityRevolvingCreditConfig>{
              'aupay': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 3000,
                creditLimit: 100000,
              ),
            },
          ),
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror:
                AssetRevolvingCreditConfigStore.encodeMirrorValue(
              <String, AssetLiabilityRevolvingCreditConfig>{
                'aupay': const AssetLiabilityRevolvingCreditConfig(
                  monthlyAmount: 99999,
                  creditLimit: 999999,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // ローカル値(3000)が維持され、ミラー値(99999)では上書きされない。
      final local = await const AssetRevolvingCreditConfigStore().load();
      expect(local['aupay']!.monthlyAmount, 3000);

      await _unmount(tester);
    });

    testWidgets('main account syncs from server mirror on a fresh device', (
      tester,
    ) async {
      // 端末B はローカル空(別ブラウザ/別ログイン)で起動する。
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugMainAccountMirror: <String, dynamic>{'id': 'smbc_otsuka'},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 端末A のメイン口座IDが起動時に復元され、ローカルへも書き戻される。
      expect(
        await const AssetManagementMainAccountStore().load(),
        'smbc_otsuka',
      );

      await _unmount(tester);
    });

    testWidgets('watchlist syncs from server mirror on a fresh device', (
      tester,
    ) async {
      // 端末A が保存したウォッチリストを集約ミラー値へエンコードする。
      final mirrorValue = AssetWatchlistService.encodeMirrorValue(
        <AssetWatchlistEntry>[
          AssetWatchlistEntry(
            assetType: 'gold',
            group: 'invest',
            memo: 'hedge',
            addedAt: DateTime.utc(2026, 6, 14),
          ),
        ],
      );

      // 端末B はローカル空で起動する。
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugWatchlistMirror: mirrorValue,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 起動時にミラーから復元され、端末B のローカルにも書き戻される。
      final synced = await const AssetWatchlistService().loadEntries();
      expect(synced.map((e) => e.assetType), contains('gold'));

      await _unmount(tester);
    });

    testWidgets('remote inflow tombstone removes the matching local chip', (
      tester,
    ) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflows_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'keep_me',
            'date': DateTime(now.year, now.month, 10).toUtc().toIso8601String(),
            'amount': 5000,
            'label': '残す入金',
          },
          <String, dynamic>{
            'id': 'delete_me',
            'date': DateTime(now.year, now.month, 12).toUtc().toIso8601String(),
            'amount': 8000,
            'label': '他端末で削除',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末が delete_me を削除した状態をミラー経由で注入。
      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugInflowDeletedIdsMirror: <String, dynamic>{
              'ids': <String>['delete_me'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_chip_keep_me')),
      );
      expect(
        find.byKey(const Key('asset_inflow_chip_keep_me')),
        findsOneWidget,
      );
      // 削除トゥームストーンが伝播し、該当チップは消えている。
      expect(
        find.byKey(const Key('asset_inflow_chip_delete_me')),
        findsNothing,
      );

      await _unmount(tester);
    });

    testWidgets('hidden override removes an essential section', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_section_overrides_v1': jsonEncode(
          <String, String>{'calendar': 'hidden'},
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('asset_calendar_prev_month')), findsNothing);

      await _unmount(tester);
    });

    testWidgets('shortfall warning appears and clears via expected inflow', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 10000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // モビット既定支払日15日の予定額が現金1万を超え、ショート警告が出る。
      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
      );
      expect(find.textContaining('回避ライン'), findsOneWidget);
      expect(
        find.byKey(const Key('asset_shift_payment_mobit')),
        findsOneWidget,
      );

      // 回避ライン額がプリフィルされた入金予定を登録すると警告が消える。
      await tester.tap(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('追加'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
        findsNothing,
      );
      expect(find.textContaining('回避ライン'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('recurring inflow before payday prevents the shortfall', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r_cover',
            'day_of_month': 14,
            'amount': 100000,
            'label': '給料前入金',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 10000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 14日の繰り返し入金が15日のモビット返済を覆い、警告は出ない。
      expect(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
        findsNothing,
      );
      expect(find.textContaining('回避ライン'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('post-payday inflow keeps warning but shift previews clear', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r_late',
            'day_of_month': 20,
            'amount': 100000,
            'label': '後半入金',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 10000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 入金が返済日(15日)より後ろなので警告は残る。
      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
      );
      expect(find.textContaining('回避ライン'), findsOneWidget);
      // ただし26日へ移せば20日の入金で賄えるため、事前判定が「回避できます」。
      expect(find.textContaining('を26日へ(回避できます)'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('mirror update notice offers and applies remote prefs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1': 'minimum',
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugMirrorPrefsRows: <Map<String, dynamic>>[
              <String, dynamic>{
                'pref_key': 'display_mode',
                'value': const <String, dynamic>{'mode': 'standard'},
                'updated_at': DateTime.now()
                    .add(const Duration(hours: 1))
                    .toUtc()
                    .toIso8601String(),
              },
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('他端末で表示設定が更新されています'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('asset_display_mode_minimum')),
            )
            .selected,
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('取り込む'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // 取り込み前に「旧 → 新」差分プレビューで確認させる。
      expect(find.text('表示設定の取り込みプレビュー'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('表示モード: ミニマム → 標準'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('asset_mirror_diff_apply')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('asset_display_mode_standard')),
            )
            .selected,
        isTrue,
      );

      await _unmount(tester);
    });

    testWidgets('sync status banner shows logged-out state', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 300));

      // 未ログイン (スモークは未認証) → 全体バナーが「この端末のみ」を明示。
      await tester.ensureVisible(
        find.byKey(const Key('asset_sync_status_chip')),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('asset_sync_status_chip')),
          matching: find.textContaining('この端末にのみ保存'),
        ),
        findsOneWidget,
      );

      await _unmount(tester);
    });

    testWidgets('unsynced badge appears for local-only watchlist', (
      tester,
    ) async {
      // ローカルにのみウォッチリストがある (未認証 = サーバ未同期) 状態。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': 'invest',
            'memo': 'hedge',
            'addedAt': DateTime.utc(2026, 6, 14).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // ウォッチリストが localOnly → 未同期バッジが出る。
      await tester.ensureVisible(
        find.byKey(const Key('asset_unsynced_badge_row')),
      );
      expect(
        find.byKey(const Key('asset_unsynced_badge_watchlist')),
        findsOneWidget,
      );
      expect(find.textContaining('ウォッチリスト 未同期'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('Phase B flag on: same-key conflict adopts server (LWW)', (
      tester,
    ) async {
      // ローカルに gold(group=old / タイムスタンプ未記録) があり、サーバに同じ
      // gold(group=new) がある衝突状態。union マージでは衝突キーの採否のみフラグで変わる。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': 'old',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugMirrorReadsAuthoritative: true,
            debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
              <AssetWatchlistEntry>[
                AssetWatchlistEntry(
                  assetType: 'gold',
                  group: 'new',
                  memo: '',
                  addedAt: DateTime.utc(2026, 6, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // フラグ ON: 衝突キー gold はサーバ値 (group=new) が採用される。
      final synced = await const AssetWatchlistService().loadEntries();
      final gold = synced.firstWhere((e) => e.assetType == 'gold');
      expect(gold.group, 'new');

      await _unmount(tester);
    });

    testWidgets('Phase B flag off (default): same-key conflict keeps local', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': 'old',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            // debugMirrorReadsAuthoritative 未指定 = 既定 OFF。
            debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
              <AssetWatchlistEntry>[
                AssetWatchlistEntry(
                  assetType: 'gold',
                  group: 'new',
                  memo: '',
                  addedAt: DateTime.utc(2026, 6, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // フラグ OFF: 衝突キー gold はローカル値 (group=old) を維持。
      final local = await const AssetWatchlistService().loadEntries();
      final gold = local.firstWhere((e) => e.assetType == 'gold');
      expect(gold.group, 'old');

      await _unmount(tester);
    });

    testWidgets('revolving union-merge: server card fills in, local card kept',
        (
      tester,
    ) async {
      // 端末B はローカルに別カードのリボ設定だけ持つ (auPAY は未設定)。
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
          AssetRevolvingCreditConfigStore.encodeMirrorValue(
            <String, AssetLiabilityRevolvingCreditConfig>{
              'other_card': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 3000,
                creditLimit: 100000,
              ),
            },
          ),
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 端末A が auPAY のリボ設定をサーバへ保存済みの状態をミラー注入。
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror:
                AssetRevolvingCreditConfigStore.encodeMirrorValue(
              <String, AssetLiabilityRevolvingCreditConfig>{
                'aupay_card': const AssetLiabilityRevolvingCreditConfig(
                  monthlyAmount: 10000,
                  creditLimit: 500000,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // union マージ: サーバの auPAY が反映され、かつローカルの別カードも維持。
      final merged = await const AssetRevolvingCreditConfigStore().load();
      expect(merged.keys, containsAll(<String>['other_card', 'aupay_card']));
      expect(merged['aupay_card']!.monthlyAmount, 10000);
      expect(merged['aupay_card']!.creditLimit, 500000);
      expect(merged['other_card']!.monthlyAmount, 3000);

      await _unmount(tester);
    });

    testWidgets('watchlist union-merge: server entry fills in, local kept', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'local_only',
            'group': '',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
              <AssetWatchlistEntry>[
                AssetWatchlistEntry(
                  assetType: 'server_only',
                  group: 'invest',
                  memo: '',
                  addedAt: DateTime.utc(2026, 6, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final merged = await const AssetWatchlistService().loadEntries();
      expect(
        merged.map((e) => e.assetType),
        containsAll(<String>['local_only', 'server_only']),
      );

      await _unmount(tester);
    });

    testWidgets('debt-override union-merge: server day fills in, local kept', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // ローカルは debt_a の支払日上書きを持ち、サーバは debt_b を持つ状態。
      final repo = _FakeDebtOverrideRepository(<String, int>{'debt_a': 27});

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            assetLiabilityRepository: repo,
            debugDebtOverridesMirror: const <String, dynamic>{'debt_b': 5},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // union マージ: ローカルの debt_a を維持しつつサーバの debt_b を取り込み、repo へ保存。
      expect(repo.savedDebtOverrides, isNotNull);
      expect(repo.savedDebtOverrides!['debt_a'], 27);
      expect(repo.savedDebtOverrides!['debt_b'], 5);

      await _unmount(tester);
    });

    testWidgets('revolving deletion tombstone removes local config', (
      tester,
    ) async {
      // ローカルに aupay_card / keep_card のリボ設定がある。
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
          AssetRevolvingCreditConfigStore.encodeMirrorValue(
            <String, AssetLiabilityRevolvingCreditConfig>{
              'aupay_card': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 10000,
                creditLimit: 500000,
              ),
              'keep_card': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 3000,
                creditLimit: 100000,
              ),
            },
          ),
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末で aupay_card を削除した状態を削除トゥームストーンで注入。
      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugRevolvingDeletedMirror: <String, dynamic>{
              'ids': <String>['aupay_card'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 削除が伝播し aupay_card はローカルから消え、keep_card は残る。
      final local = await const AssetRevolvingCreditConfigStore().load();
      expect(local.keys, isNot(contains('aupay_card')));
      expect(local.keys, contains('keep_card'));

      await _unmount(tester);
    });

    testWidgets('watchlist deletion tombstone removes local entry', (
      tester,
    ) async {
      // ローカルに gold / btc のウォッチリスト項目がある。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': '',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
          <String, dynamic>{
            'assetType': 'btc',
            'group': '',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末で gold を削除した状態を削除トゥームストーンで注入。
      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugWatchlistDeletedMirror: <String, dynamic>{
              'ids': <String>['gold'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 削除が伝播し gold はローカルから消え、btc は残る。
      final local = await const AssetWatchlistService().loadEntries();
      expect(local.map((e) => e.assetType), isNot(contains('gold')));
      expect(local.map((e) => e.assetType), contains('btc'));

      await _unmount(tester);
    });

    testWidgets(
      'tombstoned entry is not resurfaced when the server mirror still '
      'contains it (review #1)',
      (tester) async {
        // ローカルに gold / btc。サーバ集約ミラーは依然 gold を含む状態でも、
        // 削除トゥームストーンを先に取込む (pull→restore 直列化) ので、union
        // マージが gold を復活させないことを保証する。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'assetType': 'gold',
              'group': '',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
            <String, dynamic>{
              'assetType': 'btc',
              'group': '',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
          ]),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              // サーバミラーはまだ gold を持つ (復活ベクタ)。
              debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
                <AssetWatchlistEntry>[
                  AssetWatchlistEntry(
                    assetType: 'gold',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                  AssetWatchlistEntry(
                    assetType: 'btc',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                ],
              ),
              // 同時に gold の削除トゥームストーンが届く。
              debugWatchlistDeletedMirror: const <String, dynamic>{
                'ids': <String>['gold'],
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final local = await const AssetWatchlistService().loadEntries();
        expect(local.map((e) => e.assetType), isNot(contains('gold')));
        expect(local.map((e) => e.assetType), contains('btc'));

        await _unmount(tester);
      },
    );

    testWidgets(
      'additive merge realigns the local LWW timestamp even with flag off '
      '(review #2)',
      (tester) async {
        // ローカルは 'shared' のみ。サーバは 'shared' + 'extra' を持つので、
        // additive 追加のみ (localHasExtra=false → バックフィル無し) になる。
        // この経路は旧実装だと adoptConflicts=false で markChanged されず、
        // ローカル更新時刻が null のまま据え置かれていた。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'assetType': 'shared',
              'group': '',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
          ]),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
                <AssetWatchlistEntry>[
                  AssetWatchlistEntry(
                    assetType: 'shared',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                  AssetWatchlistEntry(
                    assetType: 'extra',
                    group: 'invest',
                    memo: '',
                    addedAt: DateTime.utc(2026, 6, 14),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // additive マージでもローカル更新時刻が整合される。
        final ts = await const AssetSyncTimestampStore().loadTimestamp(
          'watchlist_entries',
        );
        expect(ts, isNotNull);

        await _unmount(tester);
      },
    );
  });
}
