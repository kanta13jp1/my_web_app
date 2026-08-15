import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_account_shortfall_basis_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const planning = AssetLiabilityPlanningService();
  const service = AssetAccountShortfallBasisService();

  /// 現金 1 万円 / モビット返済 3 万円 (現金から引き落とし) で不足する構成。
  AssetLiabilityWorkbook buildShortWorkbook({
    List<AssetLiabilityIncomePlan> incomePlans =
        const <AssetLiabilityIncomePlan>[],
  }) {
    return planning.buildWorkbook(
      latestSnapshot: const <String, double>{'cash': 10000, 'mobit': -500000},
      baseDate: DateTime(2026, 5, 1),
      monthlyPaymentOverrides: const <String, double>{'mobit': 30000},
      paymentSourceAccountIds: const <String, String>{'mobit': 'custom_cash'},
      incomePlans: incomePlans,
    );
  }

  test('明細と合計が見込み残高の計算式と一致する', () {
    final workbook = buildShortWorkbook();
    final basis = service.buildBasis(
      workbook: workbook,
      accountId: 'custom_cash',
    );

    expect(basis, isNotNull);
    expect(basis!.currentBalance, 10000);
    expect(basis.paymentLines, hasLength(1));
    // 表示名はスナップショットのキーがそのまま入る (テスト fixture では 'mobit')。
    expect(basis.paymentLines.single.name, 'mobit');
    expect(basis.paymentLines.single.amount, 30000);
    expect(basis.paymentTotal, 30000);
    expect(basis.incomeLines, isEmpty);
    // 現在残高 10,000 − 引き落とし 30,000 = -20,000
    expect(basis.projectedBalance, -20000);
    expect(basis.shortfall, 20000);
  });

  test('入金先未設定の収入予定があると原因を incomeDestinationUnassigned と診断する', () {
    // 収入自体は登録されているが destinationAccountId が無い = 口座別資金繰りに
    // 反映されない。「給料は入るのに不足と出る」の最有力原因。
    final workbook = buildShortWorkbook(
      incomePlans: <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'income_salary',
          date: DateTime(2026, 5, 25),
          name: '給料',
          amount: 200000,
          destinationAccountId: null,
          destinationAccountName: null,
          received: false,
        ),
      ],
    );
    final basis = service.buildBasis(
      workbook: workbook,
      accountId: 'custom_cash',
    );

    expect(basis, isNotNull);
    expect(basis!.incomeLines, isEmpty, reason: '口座別には反映されない');
    expect(basis.cause, AssetAccountShortfallCause.incomeDestinationUnassigned);
    expect(basis.unassignedIncomeTotal, 200000);
    expect(basis.unassignedIncomeNames, contains('給料'));
    // 未設定収入 (20万) が不足 (2万) を上回る = 設定すれば解消し得る。
    expect(basis.unassignedIncomeCouldCover, isTrue);
  });

  test('入金先を設定すると口座別に反映され原因診断も変わる', () {
    final workbook = buildShortWorkbook(
      incomePlans: <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'income_salary',
          date: DateTime(2026, 5, 25),
          name: '給料',
          amount: 200000,
          destinationAccountId: 'custom_cash',
          destinationAccountName: null,
          received: false,
        ),
      ],
    );
    final basis = service.buildBasis(
      workbook: workbook,
      accountId: 'custom_cash',
    );

    expect(basis, isNotNull);
    expect(basis!.incomeLines, hasLength(1));
    expect(basis.incomeTotal, 200000);
    // 10,000 − 30,000 + 200,000 = 180,000 → 不足しない
    expect(basis.projectedBalance, 180000);
    expect(basis.shortfall, 0);
  });

  test('この口座宛ての入金があっても足りなければ incomeInsufficient', () {
    final workbook = buildShortWorkbook(
      incomePlans: <AssetLiabilityIncomePlan>[
        AssetLiabilityIncomePlan(
          id: 'income_small',
          date: DateTime(2026, 5, 25),
          name: '雑収入',
          amount: 5000,
          destinationAccountId: 'custom_cash',
          destinationAccountName: null,
          received: false,
        ),
      ],
    );
    final basis = service.buildBasis(
      workbook: workbook,
      accountId: 'custom_cash',
    );

    expect(basis, isNotNull);
    expect(basis!.cause, AssetAccountShortfallCause.incomeInsufficient);
    // 10,000 − 30,000 + 5,000 = -15,000
    expect(basis.projectedBalance, -15000);
    expect(basis.unassignedIncomeCouldCover, isFalse);
  });

  test('収入予定が全く無ければ noIncomeForAccount', () {
    final workbook = buildShortWorkbook();
    final basis = service.buildBasis(
      workbook: workbook,
      accountId: 'custom_cash',
    );

    expect(basis, isNotNull);
    expect(basis!.cause, AssetAccountShortfallCause.noIncomeForAccount);
    expect(basis.unassignedIncomeTotal, 0);
    expect(basis.unassignedIncomeCouldCover, isFalse);
  });

  test('存在しない口座IDでは null を返す', () {
    final workbook = buildShortWorkbook();
    expect(
      service.buildBasis(workbook: workbook, accountId: 'no_such_account'),
      isNull,
    );
  });
}
