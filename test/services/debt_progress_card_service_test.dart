import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const service = DebtProgressCardService();
  final baseDate = DateTime(2026, 7, 1);

  AssetLiabilityWorkbook workbookWith({
    required Map<String, double> snapshot,
    Map<String, double> payments = const <String, double>{},
  }) {
    return planner.buildWorkbook(
      latestSnapshot: snapshot,
      baseDate: baseDate,
      monthlyPaymentOverrides: payments,
    );
  }

  String debtId(AssetLiabilityWorkbook workbook, String name) {
    return workbook.debtMasterRows.firstWhere((row) => row.name == name).id;
  }

  group('DebtProgressCardService.build', () {
    test('returns null when there is no debt to report', () {
      final workbook = workbookWith(
        snapshot: const <String, double>{'bank': 500000},
      );

      expect(service.build(workbook: workbook), isNull);
    });

    test('summarises total debt, monthly payment and payoff horizon', () {
      final workbook = workbookWith(
        snapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -100000,
        },
        payments: const <String, double>{'ファミペイ': 10000},
      );

      final card = service.build(workbook: workbook);

      expect(card, isNotNull);
      expect(card!.totalDebt, 100000);
      expect(card.monthlyPayment, 10000);
      expect(card.debtCount, 1);
      expect(card.payoffMonths, isNotNull);
      // 利息総額は「完済する」ときだけ意味を持つ。
      expect(card.estimatedInterest, isNotNull);
      expect(card.estimatedInterest! > 0, isTrue);
    });

    test(
      'omits the interest total when the current payment never clears the debt',
      () {
        // 月1,000円は初月利息を下回る → 完済しない。
        final workbook = workbookWith(
          snapshot: const <String, double>{
            'bank': 500000,
            'ファミペイ': -100000,
          },
          payments: const <String, double>{'ファミペイ': 1000},
        );

        final card = service.build(workbook: workbook);

        expect(card, isNotNull);
        expect(card!.payoffMonths, isNull);
        // 打ち切り時点の部分和を「完済までに払う利息」として出すと
        // 実際より小さい額を約束することになるため出さない。
        expect(card.estimatedInterest, isNull);
      },
    );
  });

  group('DebtProgressCardService month-over-month', () {
    test('is null when no prior month snapshot exists', () {
      final workbook = workbookWith(
        snapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -100000,
        },
        payments: const <String, double>{'ファミペイ': 10000},
      );

      final card = service.build(workbook: workbook);

      expect(card!.monthOverMonthDelta, isNull);
      expect(card.isImproving, isNull);
    });

    test('reports a decrease as negative delta and improving', () {
      final workbook = workbookWith(
        snapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -90000,
        },
        payments: const <String, double>{'ファミペイ': 10000},
      );
      final id = debtId(workbook, 'ファミペイ');

      final card = service.build(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{id: 100000},
      );

      expect(card!.monthOverMonthDelta, -10000);
      expect(card.isImproving, isTrue);
    });

    test(
      'excludes debts with no prior record instead of treating them as zero',
      () {
        // 🔑 前月に記録が無い負債を 0 円扱いすると「今月まるごと増えた」と
        // 出てしまい、実際は返済が進んでいるのに増加と報告する事故になる。
        final workbook = workbookWith(
          snapshot: const <String, double>{
            'bank': 500000,
            'ファミペイ': -90000,
            'newcard': -300000,
          },
          payments: const <String, double>{
            'ファミペイ': 10000,
            'newcard': 20000,
          },
        );
        final trackedId = debtId(workbook, 'ファミペイ');

        final card = service.build(
          workbook: workbook,
          priorBalancesByAccountId: <String, double>{trackedId: 100000},
        );

        // 記録のある1件だけで比較する = -10,000 (新規カードの30万は混ぜない)。
        expect(card!.monthOverMonthDelta, -10000);
        expect(card.isImproving, isTrue);
        // 残債総額そのものは全件の合計であることは変わらない。
        expect(card.totalDebt, 390000);
        expect(card.debtCount, 2);
      },
    );

    test('is null when none of the current debts have a prior record', () {
      final workbook = workbookWith(
        snapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -90000,
        },
        payments: const <String, double>{'ファミペイ': 10000},
      );

      final card = service.build(
        workbook: workbook,
        priorBalancesByAccountId: const <String, double>{
          'unrelated-account': 100000,
        },
      );

      expect(card!.monthOverMonthDelta, isNull);
    });
  });

  group('DebtProgressCardService.buildDraftText', () {
    DebtProgressCardData card({
      int? payoffMonths = 38,
      double? interest = 234567,
      double? delta = -50000,
    }) =>
        DebtProgressCardData(
          totalDebt: 1234567,
          monthlyPayment: 45000,
          payoffMonths: payoffMonths,
          estimatedInterest: interest,
          monthOverMonthDelta: delta,
          debtCount: 3,
        );

    test('reports the disclosed figures with a signed month-over-month delta',
        () {
      final text = service.buildDraftText(
        card(),
        month: DateTime(2026, 7, 1),
      );

      expect(text, contains('2026年7月の返済報告'));
      expect(text, contains('残債 1,234,567円'));
      expect(text, contains('前月比 -50,000円'));
      expect(text, contains('今月の返済 45,000円'));
      expect(text, contains('完済まで あと3年2ヶ月'));
      expect(text, contains('利息見込み 234,567円'));
      expect(text, contains('#借金返済'));
    });

    test('omits the delta line entirely when there is no prior month', () {
      final text = service.buildDraftText(
        card(delta: null),
        month: DateTime(2026, 7, 1),
      );

      expect(text, isNot(contains('前月比')));
    });

    test('states plainly when the current payment never clears the debt', () {
      // 完済しない事実を黙って省くと報告として誠実でなくなる。
      final text = service.buildDraftText(
        card(payoffMonths: null, interest: null),
        month: DateTime(2026, 7, 1),
      );

      expect(text, contains('元金が減りません'));
      expect(text, isNot(contains('利息見込み')));
    });

    test('never leaks income, account balances or lender names', () {
      // 🔒 開示境界の回帰ガード。カード型がこれらを持たない以上、文面にも
      // 出得ないが、将来フィールドを足したときにここで気付けるようにする。
      final text = service.buildDraftText(
        card(),
        month: DateTime(2026, 7, 1),
      );

      for (final forbidden in <String>[
        '年収',
        '月収',
        '手取り',
        '口座残高',
        '残高照会',
        '勤務先',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: '$forbidden は開示範囲外');
      }
    });
  });

  group('DebtProgressCardService.buildPostPayload', () {
    DebtProgressCardData card() => const DebtProgressCardData(
          totalDebt: 1234567,
          monthlyPayment: 45000,
          payoffMonths: 38,
          estimatedInterest: 234567,
          monthOverMonthDelta: -50000,
          debtCount: 3,
        );

    test('sends the edited text verbatim instead of regenerating the draft',
        () {
      // 🔴 これが崩れると本人が直した内容が捨てられ、意図しない文が公開される。
      final payload = service.buildPostPayload(
        card(),
        month: DateTime(2026, 7, 1),
        text: '手で直した本文',
      );

      expect(payload['text'], '手で直した本文');
      expect(payload['action'], 'x.post');
    });

    test('falls back to the draft only when no text is supplied', () {
      final payload = service.buildPostPayload(
        card(),
        month: DateTime(2026, 7, 1),
      );

      expect(payload['text'], contains('2026年7月の返済報告'));
    });

    test('keeps the acquisition URL in the main post, not the reply', () {
      // リプライへ逃がすと流入が落ちることが実測済み (part346)。
      final payload = service.buildPostPayload(
        card(),
        month: DateTime(2026, 7, 1),
        text: 'x',
      );

      expect(payload['linkInReply'], false);
      expect(payload['source'], 'debt_progress_card');
      expect(payload['route'], '/asset-management');
    });
  });

  group('DebtProgressCardService card image', () {
    DebtProgressCardData card({int? payoffMonths = 38}) => DebtProgressCardData(
          totalDebt: 1234567,
          monthlyPayment: 45000,
          payoffMonths: payoffMonths,
          estimatedInterest: 234567,
          monthOverMonthDelta: -50000,
          debtCount: 3,
        );

    test('puts the user id first so the storage RLS check passes', () {
      // 🔴 RLS は (storage.foldername(name))[1] = auth.uid() を見る。
      // 先頭が userId でなくなると保存自体が落ちる。
      final path = service.buildCardStoragePath(
        userId: 'user-uuid',
        month: DateTime(2026, 7, 1),
        uniqueSuffix: '1753900000000',
      );

      expect(path.split('/').first, 'user-uuid');
      expect(path, endsWith('.png'));
      expect(path, contains('202607'));
    });

    test('does not collide when the card is rebuilt in the same month', () {
      final a = service.buildCardStoragePath(
        userId: 'u',
        month: DateTime(2026, 7, 1),
        uniqueSuffix: '1',
      );
      final b = service.buildCardStoragePath(
        userId: 'u',
        month: DateTime(2026, 7, 1),
        uniqueSuffix: '2',
      );

      expect(a, isNot(b));
    });

    test('alt text stays inside the disclosed range', () {
      final alt = service.buildCardAltText(card(), month: DateTime(2026, 7, 1));

      expect(alt, contains('残債 1,234,567円'));
      expect(alt, contains('完済まであと3年2ヶ月'));
      for (final forbidden in <String>['年収', '月収', '口座残高', '勤務先']) {
        expect(alt, isNot(contains(forbidden)));
      }
    });

    test('alt text says plainly when the debt never clears', () {
      final alt = service.buildCardAltText(
        card(payoffMonths: null),
        month: DateTime(2026, 7, 1),
      );

      expect(alt, contains('完済しない見込み'));
    });

    test('attaches media only when a url is supplied', () {
      final withMedia = service.buildPostPayload(
        card(),
        month: DateTime(2026, 7, 1),
        text: 'x',
        mediaUrl: 'https://example.com/card.png',
      );
      expect(withMedia['mediaUrl'], 'https://example.com/card.png');
      expect(withMedia['mediaType'], 'image');
      expect(withMedia['mediaAlt'], contains('返済報告カード'));

      // 画像アップロードが失敗しても投稿自体は成立させる。
      for (final empty in <String?>[null, '', '   ']) {
        final textOnly = service.buildPostPayload(
          card(),
          month: DateTime(2026, 7, 1),
          text: 'x',
          mediaUrl: empty,
        );
        expect(textOnly.containsKey('mediaUrl'), isFalse);
        expect(textOnly.containsKey('mediaAlt'), isFalse);
        expect(textOnly['text'], 'x');
      }
    });
  });

  group('DebtProgressCardData.payoffLabel', () {
    test('formats months, years and mixed spans', () {
      DebtProgressCardData card(int? months) => DebtProgressCardData(
            totalDebt: 1000,
            monthlyPayment: 100,
            payoffMonths: months,
            estimatedInterest: 0,
            monthOverMonthDelta: null,
            debtCount: 1,
          );

      expect(card(11).payoffLabel, '11ヶ月');
      expect(card(12).payoffLabel, '1年');
      expect(card(25).payoffLabel, '2年1ヶ月');
      expect(card(null).payoffLabel, isNull);
    });
  });
}
