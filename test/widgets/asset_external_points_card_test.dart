import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_external_points.dart';
import 'package:my_web_app/widgets/asset_external_points_card.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<AssetExternalPointRecord> records,
  String? statusMessage,
  VoidCallback? onAddRecord,
  ValueChanged<AssetExternalPointRecord>? onDeleteRecord,
  DateTime? now,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetExternalPointsCard(
            records: records,
            statusMessage: statusMessage,
            onAddRecord: onAddRecord,
            onDeleteRecord: onDeleteRecord,
            now: now,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AssetExternalPointsCard', () {
    testWidgets(
      'shows empty state and financial isolation notice when records are empty',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssetExternalPointsCard(
                  records: <AssetExternalPointRecord>[],
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('asset_external_points_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('asset_external_points_empty')),
          findsOneWidget,
        );
        final noticeFinder = find.byKey(
          const Key('asset_external_points_notice'),
        );
        expect(noticeFinder, findsOneWidget);
        expect(
          find.descendant(
            of: noticeFinder,
            matching: find.textContaining('純資産・手元現金・月次支出には合算しません'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: noticeFinder,
            matching: find.textContaining('会員番号・取引番号・POS番号は入力しないでください'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('asset_external_points_add')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders Keio and V-Point summaries, history details, and statusMessage',
      (tester) async {
        final records = <AssetExternalPointRecord>[
          AssetExternalPointRecord(
            id: 'ep_keio_1',
            programName: AssetExternalPointPresets.keio,
            observedAt: DateTime(2026, 11, 21, 14, 30),
            balanceAfter: 105,
            deltaPoints: 25,
            balanceBefore: 80,
            expiringPoints: 20,
            expiresOn: DateTime(2027, 4, 29),
            merchant: 'サンプル書店',
            pointTargetAmountYen: 840,
            memo: '書籍購入',
          ),
          AssetExternalPointRecord(
            id: 'ep_v_1',
            programName: 'Vポイント',
            observedAt: DateTime(2026, 11, 20, 10, 15),
            balanceAfter: 951,
            deltaPoints: -50,
            balanceBefore: 1001,
            merchant: 'ファミリーマート',
            memo: 'ポイント利用',
          ),
        ];

        await _pumpCard(
          tester,
          records: records,
          statusMessage: 'ローカル保存済み（オフライン）',
          now: DateTime(2026, 11, 21),
        );

        expect(
          find.byKey(const Key('asset_external_points_empty')),
          findsNothing,
        );
        expect(find.text('ローカル保存済み（オフライン）'), findsOneWidget);
        expect(find.text('京王ポイント'), findsWidgets);
        expect(find.text('105 P'), findsOneWidget);
        expect(find.textContaining('20 P'), findsWidgets);
        expect(find.textContaining('2027/04/29'), findsWidgets);
        expect(find.text('Vポイント'), findsWidgets);
        expect(find.text('951 P'), findsOneWidget);
        expect(find.text('+25 P'), findsOneWidget);
        expect(find.text('-50 P'), findsOneWidget);
        expect(find.text('80 P → 105 P'), findsOneWidget);
        expect(find.text('1,001 P → 951 P'), findsOneWidget);
        expect(find.text('加盟店: サンプル書店'), findsOneWidget);
        expect(
          find.text('ポイント対象額: 840円（参考・支出計上外）'),
          findsOneWidget,
        );
        expect(find.text('メモ: 書籍購入'), findsOneWidget);
      },
    );

    testWidgets(
      'highlights expiringSoon and expired badges with liveRegion',
      (tester) async {
        final records = <AssetExternalPointRecord>[
          AssetExternalPointRecord(
            id: 'ep_soon',
            programName: AssetExternalPointPresets.keio,
            observedAt: DateTime(2026, 11, 21, 9, 0),
            balanceAfter: 120,
            expiringPoints: 20,
            expiresOn: DateTime(2026, 12, 1),
          ),
          AssetExternalPointRecord(
            id: 'ep_expired',
            programName: 'Vポイント',
            observedAt: DateTime(2026, 11, 20, 9, 0),
            balanceAfter: 500,
            expiringPoints: 80,
            expiresOn: DateTime(2026, 11, 10),
          ),
        ];

        await _pumpCard(
          tester,
          records: records,
          now: DateTime(2026, 11, 21),
        );

        expect(find.textContaining('失効間近注意'), findsOneWidget);
        expect(find.textContaining('失効期限切れ注意'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && (widget.properties.liveRegion ?? false),
          ),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('fires onAddRecord and onDeleteRecord callbacks', (
      tester,
    ) async {
      var addTapped = false;
      AssetExternalPointRecord? deletedRecord;
      final target = AssetExternalPointRecord(
        id: 'ep_del_1',
        programName: AssetExternalPointPresets.keio,
        observedAt: DateTime(2026, 11, 21, 12, 0),
        balanceAfter: 105,
        deltaPoints: 25,
        balanceBefore: 80,
      );

      await _pumpCard(
        tester,
        records: <AssetExternalPointRecord>[target],
        onAddRecord: () => addTapped = true,
        onDeleteRecord: (record) => deletedRecord = record,
      );

      final addButton = find.byKey(const Key('asset_external_points_add'));
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();
      expect(addTapped, isTrue);

      final deleteButton = find.byKey(
        const Key('asset_external_points_delete_ep_del_1'),
      );
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pump();
      expect(deletedRecord, equals(target));
    });
  });

  group('showAssetExternalPointEditorDialog', () {
    testWidgets(
      'validates required fields and returns record from full-width input, merchant, and expiry',
      (tester) async {
        AssetExternalPointRecord? savedRecord;
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      savedRecord = await showAssetExternalPointEditorDialog(
                        context,
                        initialObservedAt: DateTime(2027, 4, 15, 18, 5),
                      );
                      completed = true;
                    },
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('会員番号・取引番号・端末番号は入力しないでください'),
          findsOneWidget,
        );

        // 必須の残高が空のまま保存してもバリデーションによりダイアログは閉じない。
        await tester.tap(find.byKey(const Key('asset_external_point_save')));
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('残高を入力してください'), findsOneWidget);
        expect(completed, isFalse);

        // プログラム名を空にした場合も閉じない。
        final programField = find.byKey(
          const Key('asset_external_point_program_field'),
        );
        await tester.ensureVisible(programField);
        await tester.enterText(programField, '');
        await tester.tap(find.byKey(const Key('asset_external_point_save')));
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('プログラム名を入力してください'), findsOneWidget);

        // プリセット ChoiceChip で Vポイント -> 京王ポイントを選択し、全角数字で入力。
        final vPointChip = find.widgetWithText(ChoiceChip, 'Vポイント');
        await tester.ensureVisible(vPointChip);
        await tester.tap(vPointChip);
        await tester.pump();

        final keioChip = find.widgetWithText(ChoiceChip, '京王ポイント');
        await tester.ensureVisible(keioChip);
        await tester.tap(keioChip);
        await tester.pump();

        final balanceAfterField = find.byKey(
          const Key('asset_external_point_balance_after_field'),
        );
        await tester.ensureVisible(balanceAfterField);
        await tester.enterText(balanceAfterField, '１０５');

        final deltaField = find.byKey(
          const Key('asset_external_point_delta_field'),
        );
        await tester.ensureVisible(deltaField);
        await tester.enterText(deltaField, '＋２５');

        final balanceBeforeField = find.byKey(
          const Key('asset_external_point_balance_before_field'),
        );
        await tester.ensureVisible(balanceBeforeField);
        await tester.enterText(balanceBeforeField, '８０');

        final merchantField = find.byKey(
          const Key('asset_external_point_merchant_field'),
        );
        await tester.ensureVisible(merchantField);
        await tester.enterText(merchantField, 'サンプル書店');

        final expiringPointsField = find.byKey(
          const Key('asset_external_point_expiring_points_field'),
        );
        await tester.ensureVisible(expiringPointsField);
        await tester.enterText(expiringPointsField, '20');

        final expiresOnPicker = find.byKey(
          const Key('asset_external_point_expires_on_picker'),
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(expiresOnPicker),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(expiresOnPicker.hitTestable());
        await tester.pumpAndSettle();

        final datePicker = find.byType(DatePickerDialog);
        expect(datePicker, findsOneWidget);
        await tester.tap(
          find.descendant(of: datePicker, matching: find.text('29')),
        );
        await tester.tap(
          find.descendant(of: datePicker, matching: find.text('OK')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2027/04/29'), findsOneWidget);

        final targetAmountField = find.byKey(
          const Key('asset_external_point_target_amount_field'),
        );
        await tester.ensureVisible(targetAmountField);
        await tester.enterText(targetAmountField, '840');

        final memoField = find.byKey(
          const Key('asset_external_point_memo_field'),
        );
        await tester.ensureVisible(memoField);
        await tester.enterText(memoField, 'レシート記録');

        await tester.tap(find.byKey(const Key('asset_external_point_save')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(completed, isTrue);
        final record = savedRecord;
        expect(record, isNotNull);
        if (record == null) {
          return;
        }
        expect(record.id, startsWith('ep_'));
        expect(record.programName, '京王ポイント');
        expect(record.balanceAfter, 105);
        expect(record.deltaPoints, 25);
        expect(record.balanceBefore, 80);
        expect(record.observedAt, DateTime(2027, 4, 15, 18, 5));
        expect(record.merchant, 'サンプル書店');
        expect(record.expiringPoints, 20);
        expect(record.expiresOn, DateTime(2027, 4, 29));
        expect(record.pointTargetAmountYen, 840);
        expect(record.memo, 'レシート記録');
      },
    );

    testWidgets(
      'returns null on cancel and supports clearing expiresOn',
      (tester) async {
        AssetExternalPointRecord? savedRecord;
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      savedRecord = await showAssetExternalPointEditorDialog(
                        context,
                        initialObservedAt: DateTime(2027, 4, 15, 10, 0),
                      );
                      completed = true;
                    },
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final expiresOnPicker = find.byKey(
          const Key('asset_external_point_expires_on_picker'),
        );
        await tester.ensureVisible(expiresOnPicker);
        await tester.tap(expiresOnPicker);
        await tester.pumpAndSettle();

        final datePicker = find.byType(DatePickerDialog);
        await tester.tap(
          find.descendant(of: datePicker, matching: find.text('29')),
        );
        await tester.tap(
          find.descendant(of: datePicker, matching: find.text('OK')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2027/04/29'), findsOneWidget);

        final clearButton = find.byKey(
          const Key('asset_external_point_expires_on_clear'),
        );
        await tester.ensureVisible(clearButton);
        await tester.tap(clearButton);
        await tester.pump();
        expect(find.text('未設定'), findsOneWidget);

        await tester.tap(find.byKey(const Key('asset_external_point_cancel')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(completed, isTrue);
        expect(savedRecord, isNull);
      },
    );
  });
}
