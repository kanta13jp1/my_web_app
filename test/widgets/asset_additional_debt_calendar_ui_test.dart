import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_additional_debt_calendar_dialog.dart';
import 'package:my_web_app/widgets/asset_borrowing_calendar_badge.dart';

void main() {
  group('AssetBorrowingCalendarBadge', () {
    testWidgets(
      'renders all debt labels, scales cleanly at 2.0x, and passes a11y contrast',
      (tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 240,
                      child: AssetBorrowingCalendarBadge(
                        hasBorrowing: true,
                        hasRevolvingUsage: true,
                        hasDebtGuardViolation: true,
                        preserveTextScale: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(FittedBox), findsNothing);
          expect(find.text('借入'), findsOneWidget);
          expect(find.text('リボ'), findsOneWidget);
          expect(find.text('借金違反'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          semantics.dispose();
        }
      },
    );

    test('resolves background color priority correctly', () {
      expect(
        AssetBorrowingCalendarBadge.cellBackgroundFor(
          hasBorrowing: false,
          hasRevolvingUsage: false,
          hasDebtGuardViolation: false,
        ),
        isNull,
      );
      expect(
        AssetBorrowingCalendarBadge.cellBackgroundFor(
          hasBorrowing: true,
          hasRevolvingUsage: false,
          hasDebtGuardViolation: false,
        ),
        const Color(0xFFFEF3C7),
      );
      expect(
        AssetBorrowingCalendarBadge.cellBackgroundFor(
          hasBorrowing: true,
          hasRevolvingUsage: true,
          hasDebtGuardViolation: false,
        ),
        const Color(0xFFFFE4E6),
      );
    });
  });

  group('AssetAdditionalDebtCalendarDialog', () {
    testWidgets(
      'validates invalid amount and submits cashing and revolving drafts cleanly',
      (tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        try {
          AssetAdditionalDebtCalendarDraft? captured;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      captured =
                          await showDialog<AssetAdditionalDebtCalendarDraft>(
                        context: context,
                        builder: (_) => AssetAdditionalDebtCalendarDialog(
                          initialDate: DateTime(2026, 7, 10),
                          accountOptions:
                              const <AssetAdditionalDebtAccountOption>[
                            AssetAdditionalDebtAccountOption(
                              id: 'mobit',
                              name: 'モビット',
                            ),
                            AssetAdditionalDebtAccountOption(
                              id: 'famipay_card',
                              name: 'ファミペイ',
                              isRevolvingCard: true,
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('開く'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('開く'));
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

          // 0円送信時はインラインエラーを表示しダイアログを閉じない
          await tester.enterText(
            find.byKey(const Key('asset_additional_debt_amount_field')),
            '0',
          );
          await tester.tap(
            find.byKey(const Key('asset_additional_debt_submit_button')),
          );
          await tester.pump();

          expect(
            find.byKey(const Key('asset_additional_debt_error_text')),
            findsOneWidget,
          );
          expect(find.text('1円以上の金額を入力してください'), findsOneWidget);
          expect(captured, isNull);

          // 正常金額 + Debt Guard チェックでキャッシングとして確定
          await tester.enterText(
            find.byKey(const Key('asset_additional_debt_amount_field')),
            '15,000',
          );
          await tester.enterText(
            find.byKey(const Key('asset_additional_debt_memo_field')),
            'ATM借入',
          );
          await tester.tap(
            find.byKey(const Key('asset_additional_debt_guard_checkbox')),
          );
          await tester.pump();
          await tester.tap(
            find.byKey(const Key('asset_additional_debt_submit_button')),
          );
          await tester.pumpAndSettle();

          expect(captured, isNotNull);
          expect(captured!.kind, AssetAdditionalDebtRecordKind.cashing);
          expect(captured!.amount, 15000);
          expect(captured!.accountId, 'mobit');
          expect(captured!.accountName, 'モビット');
          expect(captured!.memo, 'ATM借入');
          expect(captured!.recordDebtGuardViolation, isTrue);

          // 再度開いてリボ払い利用へ切り替えて確定
          captured = null;
          await tester.tap(find.text('開く'));
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(const Key('asset_additional_debt_kind_field')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('リボ払い利用（現金引落なし）').last);
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('asset_additional_debt_amount_field')),
            '4800',
          );
          await tester.tap(
            find.byKey(const Key('asset_additional_debt_submit_button')),
          );
          await tester.pumpAndSettle();

          expect(captured, isNotNull);
          expect(captured!.kind, AssetAdditionalDebtRecordKind.revolvingUsage);
          expect(captured!.amount, 4800);
          expect(captured!.accountId, 'famipay_card');
          expect(captured!.recordDebtGuardViolation, isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  });
}
