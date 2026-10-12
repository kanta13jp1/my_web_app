import 'dart:convert';
import 'dart:math';

import 'ai_hub_chat_service.dart';
import 'asset_chat_privacy_settings_service.dart';

class SavingsPlanProposalInput {
  const SavingsPlanProposalInput({
    required this.cashBalance,
    required this.monthlyIncome,
    required this.monthlyCommitments,
    required this.observedLivingExpense,
    required this.recordedDays,
    required this.estimatedPayments,
  });
  final int cashBalance;
  final int? monthlyIncome;
  final int monthlyCommitments;
  final int observedLivingExpense;
  final int recordedDays;
  final bool estimatedPayments;
}

class SavingsPlanProposal {
  const SavingsPlanProposal({
    required this.input,
    required this.livingCosts,
    required this.reserve,
    required this.rationale,
    required this.usedAi,
    required this.source,
  });
  final SavingsPlanProposalInput input;
  final int livingCosts;
  final int reserve;
  final String rationale;
  final bool usedAi;
  final String source;
  int get protectedCash => input.monthlyCommitments + livingCosts + reserve;
  int get availableSavings => max(0, input.cashBalance - protectedCash);
  int get reserveShortfall => max(0, protectedCash - input.cashBalance);
}

/// Account totals remain grounded in app data. AI proposes only living/reserve
/// amounts; it never changes balances, payment facts, dates, or the target.
class SavingsPlanProposalService {
  SavingsPlanProposalService({
    Future<String> Function(String)? generate,
    Future<bool> Function()? allowExternalAi,
  })  : _generate = generate ?? _request,
        _allowExternalAi = allowExternalAi ?? _privacyAllows;

  final Future<String> Function(String) _generate;
  final Future<bool> Function() _allowExternalAi;

  static Future<bool> _privacyAllows() async =>
      !(await const AssetChatPrivacySettingsService().loadMaskMoneyAmounts());

  static Future<String> _request(String prompt) async {
    final response = await const AiHubChatService().sendAutoChat(
      message: prompt,
      tier: 'budget',
      maxTokens: 1200,
      traceId: 'savings-life-plan-proposal',
      routingUseCase: 'savings_life_plan',
    );
    return response.text;
  }

  Future<SavingsPlanProposal> propose(SavingsPlanProposalInput input) async {
    // Sparse expense records cannot establish a safe food/transport budget.
    // This is an editable working scenario, never a claimed personal minimum.
    final baselineLiving = max(60000, input.observedLivingExpense);
    SavingsPlanProposal fallback(String reason) => SavingsPlanProposal(
          input: input,
          livingCosts: baselineLiving,
          reserve: 10000,
          rationale: '生活費は記録済み金額と仮置き60,000円の大きい方、予備費は仮置き10,000円です。'
              '支出記録が少ない場合、必要生活費は確定できません。食事・通勤・医療を確保できるか確認してください。',
          usedAi: false,
          source: reason,
        );
    try {
      if (!await _allowExternalAi()) return fallback('AI未使用：金額を隠す設定を尊重');
      final evidence = {
        'cash_and_deposits': input.cashBalance,
        'monthly_net_income_plan': input.monthlyIncome,
        'monthly_debt_and_fixed_payments': input.monthlyCommitments,
        'recorded_variable_expense_current_cycle': input.observedLivingExpense,
        'days_with_recorded_expenses': input.recordedDays,
        'contains_estimated_payments': input.estimatedPayments,
        'working_living_budget': baselineLiving,
        'working_emergency_reserve': 10000,
      };
      final prompt = '登録された家計の集計だけを根拠に、日本語で生活設計案を提案してください。'
          '目標は1年後、翌1給与サイクルの返済・固定費・生活費・予備費を別に確保した後、同棲準備に使える自由資金100万円。収入増は現実的でないため、登録手取り据え置きで計画する。'
          '口座残高・収入・返済額・目標額を変更または創作しない。生活費を極端に削って目標を達成扱いにしない。'
          '収入増・副業・転職・賃上げ・借入・ボーナス・運用益は提案しない。支出の見直しと同棲準備の節約生活だけを提案する。記録不足は不確実として説明する。'
          '生活費案は仮置き以上、予備費案は10,000円以上とし、無理なら不足を説明する。'
          'JSONだけを返す：{"living_costs":整数,"reserve":整数,"rationale":"日本語の根拠と日々の食事・通勤・仕事・休息の方針"}。'
          'rationaleには金額・数字・達成済み・返済済みと書かず、生活方針だけを説明する。生活費は上の固定費を重複して含めない。集計：${jsonEncode(evidence)}';
      final raw = await _generate(prompt).timeout(const Duration(seconds: 30));
      var text = raw.trim();
      if (text.startsWith('```'))
        text = text
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      final value = jsonDecode(text) as Map<String, dynamic>;
      final living = value['living_costs'];
      final reserve = value['reserve'];
      final rationale = value['rationale'];
      if (living is! int ||
          living < baselineLiving ||
          living > 1000000 ||
          reserve is! int ||
          reserve < 10000 ||
          reserve > 1000000 ||
          rationale is! String ||
          rationale.length > 1200 ||
          !RegExp(r'[ぁ-んァ-ン一-龯]').hasMatch(rationale) ||
          RegExp(r'[0-9０-９]|達成済|返済済|食事を抜|水だけ|収入増|収入を増|増収|副業|転職|賃上げ|ボーナス|運用益')
              .hasMatch(rationale)) {
        return fallback('AI応答を検証できず、仮置き案を表示');
      }
      return SavingsPlanProposal(
        input: input,
        livingCosts: living,
        reserve: reserve,
        rationale: rationale,
        usedAi: true,
        source: 'AI提案（集計値を検証・保存前に確認）',
      );
    } catch (_) {
      return fallback('AIを利用できず、仮置き案を表示');
    }
  }
}
