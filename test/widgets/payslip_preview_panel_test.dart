import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/payslip_preview_panel.dart';

const _owner = 'fixture-owner';
const _path = 'fixture-owner/fixture.pdf';

Map<String, Object?> _response() => {
      'success': true,
      'status': 'preview_only',
      'persisted': false,
      'warnings': ['synthetic warning text must stay hidden'],
      'masked_text_preview': 'synthetic source must stay hidden',
      'payslip': {
        'user_id': _owner,
        'source_pdf_path': _path,
        'review_status': 'needs_review',
      },
      'parsed': {
        'pay_date': '2032-04-01',
        'company_name': 'unknown',
        'gross_amount': 0,
        'net_amount': 37,
        'taxable_amount': null,
        'social_insurance_total': null,
      },
    };

PayslipPreview? _decode(Map<String, Object?> response) =>
    PayslipPreview.fromResponse(response, owner: _owner, storagePath: _path);

void main() {
  test('旧応答・不一致の保管先や利用者・不正な必須項目を表示しない', () {
    final good = _response();
    final row = good['payslip']! as Map<String, Object?>;
    final parsed = good['parsed']! as Map<String, Object?>;
    for (final response in [
      {...good, 'status': 'parsed'},
      {...good, 'persisted': true},
      {...good, 'success': false},
      {...good, 'payslip': {...row, 'user_id': 'previous-owner'}},
      {...good, 'payslip': {...row, 'source_pdf_path': 'fixture-owner/other.pdf'}},
      {...good, 'parsed': {...parsed, 'pay_date': '2032-02-31'}},
      {...good, 'parsed': {...parsed, 'net_amount': 0}},
      {...good, 'parsed': {...parsed, 'net_amount': '37'}},
    ]) {
      expect(_decode(response), isNull);
    }
    final preview = _decode(good)!;
    expect(preview.values[PayslipPreviewField.net], '37');
    expect(preview.values[PayslipPreviewField.gross], isNull);
    expect(preview.values[PayslipPreviewField.taxable], isNull);
  });

  testWidgets('訂正候補は解析値と区別し、画面を閉じて開き直すと消去される', (tester) async {
    final preview = _decode(_response())!;
    var opened = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: opened
                  ? PayslipPreviewPanel(
                      preview: preview,
                      onDismiss: () => setState(() => opened = false),
                    )
                  : TextButton(
                      onPressed: () => setState(() => opened = true),
                      child: const Text('再表示'),
                    ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('今回の解析結果・訂正候補は未登録'), findsOneWidget);
    expect(find.textContaining('synthetic source'), findsNothing);
    expect(find.textContaining('synthetic warning'), findsNothing);
    expect(find.text('総支給額（円）　解析値　未読取・要確認'), findsOneWidget);

    Future<void> tapText(String text) async {
      final target = find.text(text);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tapText('訂正候補を入力');
    final field = find.byKey(const ValueKey(PayslipPreviewField.net));
    await tester.ensureVisible(field);
    await tester.enterText(field, '41');
    await tapText('訂正候補を見直す');
    expect(find.text('手取り額（円）　解析値　37'), findsOneWidget);
    expect(find.text('訂正候補　41'), findsOneWidget);
    await tapText('入力を破棄して閉じる');
    await tapText('再表示');
    expect(find.text('訂正候補　41'), findsNothing);
    expect(find.text('手取り額（円）　解析値　37'), findsOneWidget);
  });

  test('欠落した任意額は未取得、明示した0円は保持する', () {
    final good = _response();
    final parsed = good['parsed']! as Map<String, Object?>;
    final missing = Map<String, Object?>.of(parsed)..remove('taxable_amount');
    final absent = _decode({...good, 'parsed': missing})!;
    expect(absent.values[PayslipPreviewField.taxable], isNull);
    final explicitZero = _decode({
      ...good,
      'parsed': {...parsed, 'taxable_amount': 0, 'social_insurance_total': 0},
    })!;
    expect(explicitZero.values[PayslipPreviewField.taxable], '0');
    expect(explicitZero.values[PayslipPreviewField.insurance], '0');
    expect(explicitZero.values[PayslipPreviewField.gross], isNull);
    final missingDate = Map<String, Object?>.of(parsed)..remove('pay_date');
    expect(_decode({...good, 'parsed': missingDate}), isNull);
  });

  testWidgets('訂正額と日付の不正入力は編集状態に残し、有効な候補だけを見直せる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PayslipPreviewPanel(preview: _decode(_response())!, onDismiss: () {}),
          ),
        ),
      ),
    );

    Future<void> tapButton(String text) async {
      final button = find.widgetWithText(TextButton, text);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> enter(PayslipPreviewField field, String text) async {
      final input = find.byKey(ValueKey(field));
      await tester.ensureVisible(input);
      await tester.enterText(input, text);
    }

    await tapButton('訂正候補を入力');
    for (final invalid in ['-1', '0.5', 'NaN', '9007199254740992', '0']) {
      await enter(PayslipPreviewField.net, invalid);
      await tapButton('訂正候補を見直す');
      expect(find.text('手取り額は1円以上の整数で入力してください。'), findsOneWidget);
      expect(find.text('訂正候補　$invalid'), findsNothing);
    }
    await enter(PayslipPreviewField.net, '9007199254740991');
    await enter(PayslipPreviewField.payDate, '2032-02-30');
    await tapButton('訂正候補を見直す');
    expect(find.text('日付をYYYY-MM-DDで入力してください。'), findsOneWidget);
    await enter(PayslipPreviewField.payDate, '2032-02-29');
    await tapButton('訂正候補を見直す');
    expect(find.text('訂正候補　2032-02-29'), findsOneWidget);
    expect(find.text('訂正候補　9007199254740991'), findsOneWidget);
    expect(find.text('手取り額（円）　解析値　37'), findsOneWidget);
  });
}
