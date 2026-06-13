import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  });
}
