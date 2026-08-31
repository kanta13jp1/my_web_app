// AI 参謀室ブリーフィング: 個人の実データ(資金繰り予測 / 負債トレンド /
// 「借金しない宣言」規律)を 1 つの状況として束ね、担当部署ごとの次アクションへ
// 決定的に分解する統合レイヤ。
//
// なぜ必要か(競合対抗):
// - MoneyForward AI Cowork(2026-07)= 法人バックオフィスの請求/支払/消込/資金繰り
//   予測を複数エージェントで自律実行。ChatGPT Work(7/9)= 数時間自律で成果物を納品。
//   Motion(AI Employee SuperApp)= 名前付き AI 社員(秘書/営業/PM…)。
//   いずれも「業務を丸投げできる複数 AI 部署」を売りにし、自社の中核メタファーを
//   コモディティ化しつつある。
// - 自社の非代替 moat = ①日本語 ②個人(法人でない) ③個人 B/S の深度 ④自己経営
//   ナラティブ + X 集客ループ。本サービスはこの 4 点に賭ける: 個人の実 B/S から
//   「バラバラの名前付き社員」ではなく「1 つの状況へ協調して応答する参謀室」を
//   決定的に生成する(= Motion への差別化 = 統合性)。
//
// 設計原則(既存の asset_debt_trend_analyzer / household_tracker_share_service と同一):
// - 決定的合成(LLM 不使用)。金額はすべて Dart 側で計算し、AI には説明も任せない。
//   これは Qiita 無審査自動投稿停止の教訓(捏造を構造的に不可能化)と同じ方針。
// - 依存ゼロ(既存の純サービス 3 つと dart:math のみ)= VM ユニットテスト可能。
// - 部署の displayName/roleTitle/room は agent_org_service の
//   defaultExecutiveBlueprints と一致させる(実在の 12 部署組織と結線 = 統合性)。

library;

import 'asset_cashflow_forecast_service.dart';
import 'asset_debt_discipline_monitor.dart';
import 'asset_debt_trend_analyzer.dart';

/// 参謀室で発言する部署。agent_org_service の実在ブループリントの部分集合。
enum AdvisoryDepartment { ceo, cfo, cmo, cho, chro, planning }

/// 参謀アクションの重要度。負債トレンド系と同じ 3 段階に揃える。
enum AdvisorySeverity { info, warning, critical }

/// 部署の表示情報。agent_org_service.defaultExecutiveBlueprints と一致させる
/// (slug は実在エージェントの slug)。
class AdvisoryDepartmentProfile {
  final AdvisoryDepartment department;

  /// agent_org_service のブループリント slug(実在の担当エージェント)。
  final String slug;

  /// 例: CFO（財務部長）。
  final String displayName;

  /// 例: 最高財務責任者。
  final String roleTitle;

  /// 例: CFO室。
  final String room;

  const AdvisoryDepartmentProfile({
    required this.department,
    required this.slug,
    required this.displayName,
    required this.roleTitle,
    required this.room,
  });
}

/// 部署 → 表示プロファイル。agent_org_service と同じ値を単一箇所に持つ。
const Map<AdvisoryDepartment, AdvisoryDepartmentProfile> kAdvisoryDepartments =
    <AdvisoryDepartment, AdvisoryDepartmentProfile>{
  AdvisoryDepartment.ceo: AdvisoryDepartmentProfile(
    department: AdvisoryDepartment.ceo,
    slug: 'ceo',
    displayName: 'CEO（社長）',
    roleTitle: '代表取締役社長',
    room: 'CEO室',
  ),
  AdvisoryDepartment.cfo: AdvisoryDepartmentProfile(
    department: AdvisoryDepartment.cfo,
    slug: 'cfo',
    displayName: 'CFO（財務部長）',
    roleTitle: '最高財務責任者',
    room: 'CFO室',
  ),
  AdvisoryDepartment.cmo: AdvisoryDepartmentProfile(
    department: AdvisoryDepartment.cmo,
    slug: 'cmo',
    displayName: 'CMO（マーケティング部長）',
    roleTitle: '最高マーケティング責任者',
    room: 'CMO室',
  ),
  AdvisoryDepartment.cho: AdvisoryDepartmentProfile(
    department: AdvisoryDepartment.cho,
    slug: 'cho',
    displayName: 'CHO（健康管理部長）',
    roleTitle: '最高健康責任者',
    room: 'CHO室',
  ),
  AdvisoryDepartment.chro: AdvisoryDepartmentProfile(
    department: AdvisoryDepartment.chro,
    slug: 'chro',
    displayName: 'CHRO（人事部長）',
    roleTitle: '最高人事責任者',
    room: 'CHRO室',
  ),
  AdvisoryDepartment.planning: AdvisoryDepartmentProfile(
    department: AdvisoryDepartment.planning,
    slug: 'planning-director',
    displayName: '企画部長',
    roleTitle: '企画部長',
    room: '企画部',
  ),
};

/// 参謀室が出す 1 部署ぶんのアクション。
class AdvisoryAction {
  final AdvisoryDepartment department;
  final AdvisorySeverity severity;

  /// 由来シグナルの識別子(テスト・計測用)。例: cashflow_shortfall。
  final String signalKey;

  /// 部署の一言見出し。
  final String headline;

  /// 具体アクション(本人だけが見る画面用。金額を含んでよい)。
  final String detail;

  const AdvisoryAction({
    required this.department,
    required this.severity,
    required this.signalKey,
    required this.headline,
    required this.detail,
  });

  AdvisoryDepartmentProfile get profile => kAdvisoryDepartments[department]!;
}

/// 参謀室ブリーフィング全体。
class AdvisoryBriefing {
  final DateTime generatedAt;

  /// 重要度降順 → 部署表示順でソート済みのアクション列。
  final List<AdvisoryAction> actions;

  /// ブリーフィング総括の一文。
  final String headline;

  const AdvisoryBriefing({
    required this.generatedAt,
    required this.actions,
    required this.headline,
  });

  bool get isEmpty => actions.isEmpty;

  int get criticalCount =>
      actions.where((a) => a.severity == AdvisorySeverity.critical).length;

  int get warningCount =>
      actions.where((a) => a.severity == AdvisorySeverity.warning).length;

  int get infoCount =>
      actions.where((a) => a.severity == AdvisorySeverity.info).length;

  /// 対応に加わった部署数(重複排除)。
  int get engagedDepartmentCount =>
      actions.map((a) => a.department).toSet().length;

  AdvisorySeverity get topSeverity {
    if (criticalCount > 0) return AdvisorySeverity.critical;
    if (warningCount > 0) return AdvisorySeverity.warning;
    return AdvisorySeverity.info;
  }
}

/// 資金繰り予測 + 負債トレンド + 規律を、部署横断の参謀アクションへ決定的に束ねる。
class AssetAdvisoryBriefingService {
  const AssetAdvisoryBriefingService();

  /// [forecast] は任意(未設定 = 予測データ不足)。[debtInsights] は
  /// AssetDebtTrendAnalyzer の出力、[disciplineReport] は
  /// AssetDebtDisciplineMonitor の出力。
  AdvisoryBriefing build({
    required DateTime now,
    AssetCashflowForecast? forecast,
    List<AssetDebtTrendInsight> debtInsights = const <AssetDebtTrendInsight>[],
    AssetDebtDisciplineReport? disciplineReport,
  }) {
    final actions = <AdvisoryAction>[];

    // ── CFO: 資金繰り予測(MF AI Cowork の資金繰り予測を個人版で先回り) ──
    if (forecast != null && !forecast.isEmpty) {
      final horizon = forecast.months.length;
      if (forecast.hasShortfall) {
        final shortfall = forecast.shortfallRecoveryAmount;
        final date = forecast.firstShortfallDate!;
        actions.add(
          AdvisoryAction(
            department: AdvisoryDepartment.cfo,
            severity: AdvisorySeverity.critical,
            signalKey: 'cashflow_shortfall',
            headline: '資金ショート見込み',
            detail: '${date.month}月${date.day}日に見込み残高がマイナスへ。'
                '不足の最大幅は${formatAdvisoryYen(shortfall)}。'
                '追加借入で埋める前に、固定費の即時見直しと入金前倒しで穴を塞ぐ。',
          ),
        );
      } else if (forecast.safetyShortfallAmount > 0) {
        actions.add(
          AdvisoryAction(
            department: AdvisoryDepartment.cfo,
            severity: AdvisorySeverity.warning,
            signalKey: 'cashflow_safety',
            headline: '安全余裕を下回る見込み',
            detail: '$horizonヶ月先までの見込み最小残高が安全ライン'
                '(${formatAdvisoryYen(forecast.safetyMargin)})を割り込む。'
                '予備費${formatAdvisoryYen(forecast.safetyShortfallAmount)}を先に確保する。',
          ),
        );
      } else {
        actions.add(
          AdvisoryAction(
            department: AdvisoryDepartment.cfo,
            severity: AdvisorySeverity.info,
            signalKey: 'cashflow_clear',
            headline: '資金繰りは当面クリア',
            detail: '$horizonヶ月先まで資金ショートなし'
                '(見込み最小残高${formatAdvisoryYen(forecast.worstBalance)})。'
                'この余力は返済加速か予備費積み増しへ回す。',
          ),
        );
      }
    }

    // ── CFO: 負債トレンド(既存 analyzer の翌月アクションを参謀室へ昇格) ──
    if (debtInsights.isNotEmpty) {
      // analyzer は重要度降順でソート済み。先頭を代表として扱う。
      final worst = debtInsights.first;
      final flagged = debtInsights
          .where(
            (i) =>
                i.severity == AssetDebtTrendSeverity.critical ||
                i.severity == AssetDebtTrendSeverity.warning,
          )
          .length;
      final accounts = debtInsights.map((i) => i.accountId).toSet().length;
      actions.add(
        AdvisoryAction(
          department: AdvisoryDepartment.cfo,
          severity: _mapDebtSeverity(worst.severity),
          signalKey: 'debt_trend',
          headline: '負債トレンド: ${_debtCategoryLabel(worst.category)}',
          detail: '${worst.nextMonthAction}'
              '（監視$accounts口座 / 要対応$flagged件）',
        ),
      );
    }

    // ── CHRO: 「借金しない宣言」規律(習慣設計は人事の管掌) ──
    if (disciplineReport != null && disciplineReport.isRelevant) {
      // 誓約①(追加借入ゼロ)は前月残高が 1 件も無いと評価ループに入らず
      // (asset_debt_discipline_monitor.dart の `prior != null` ガード)、
      // newBorrowingViolations が必ず空 = zeroNewBorrowingAchieved が無条件 true になる。
      // 「評価していない」を「達成」と書くと、同じ画面の規律カードのチップ
      // (evaluated: hasPriorMonthData → 判定保留) と正面から矛盾するので、
      // 規律カード・AI プロンプトと同じく hasPriorMonthData で表現を分ける。
      final pledgeOneEvaluated = disciplineReport.hasPriorMonthData;
      if (disciplineReport.hasViolations) {
        final violation = disciplineReport.allViolations.first;
        final hasCritical = disciplineReport.allViolations
            .any((v) => v.severity == AssetDebtTrendSeverity.critical);
        final String pledgeOneLabel;
        if (!pledgeOneEvaluated) {
          pledgeOneLabel = '判定保留';
        } else {
          pledgeOneLabel =
              disciplineReport.zeroNewBorrowingAchieved ? '達成' : '未達';
        }
        actions.add(
          AdvisoryAction(
            department: AdvisoryDepartment.chro,
            severity: hasCritical
                ? AdvisorySeverity.critical
                : AdvisorySeverity.warning,
            signalKey: 'discipline_violation',
            headline: '「借金しない宣言」に違反',
            detail: '${violation.action}'
                '（誓約①カード以外の追加借入ゼロ: $pledgeOneLabel / '
                '誓約②新規利用分の25日全額返済: '
                '${disciplineReport.newUsageRepaymentAchieved ? '達成' : '未達'}）',
          ),
        );
      } else if (pledgeOneEvaluated) {
        actions.add(
          const AdvisoryAction(
            department: AdvisoryDepartment.chro,
            severity: AdvisorySeverity.info,
            signalKey: 'discipline_ok',
            headline: '規律を維持',
            detail: '今月はカード以外の追加借入ゼロ・新規利用分の25日全額返済を達成。'
                '習慣として来月も固定費の自動引落を月初に点検する。',
          ),
        );
      } else {
        actions.add(
          const AdvisoryAction(
            department: AdvisoryDepartment.chro,
            severity: AdvisorySeverity.info,
            signalKey: 'discipline_ok',
            headline: '新規利用分の25日返済を維持（追加借入は判定保留）',
            detail: '今月はカード新規利用分の返済ルールを守れています。'
                'カード以外の追加借入ゼロは前月残高が未蓄積のため判定しておらず、来月以降に有効化されます。'
                '習慣として来月も固定費の自動引落を月初に点検する。',
          ),
        );
      }
    }

    final hasFinancialCritical =
        actions.any((a) => a.severity == AdvisorySeverity.critical);
    final hasDebtCritical =
        debtInsights.any((i) => i.severity == AssetDebtTrendSeverity.critical);

    // ── CMO: 不足は借入でなく収入で埋める(moat④ = X 集客ループ) ──
    if ((forecast?.hasShortfall ?? false) || hasDebtCritical) {
      actions.add(
        const AdvisoryAction(
          department: AdvisoryDepartment.cmo,
          severity: AdvisorySeverity.info,
          signalKey: 'revenue_loop',
          headline: '穴埋めは追加借入でなく収入側で',
          detail: 'CMOより: 不足を追加借入で埋めない。負債トレンドの実測を匿名スコアボードで'
              'X投稿し、登録導線を1本増やして収入側から穴を塞ぐ。',
        ),
      );
    }

    // ── CHO: 資金ストレス局面のセルフケア(自己経営ナラティブ) ──
    if (hasFinancialCritical) {
      actions.add(
        const AdvisoryAction(
          department: AdvisoryDepartment.cho,
          severity: AdvisorySeverity.info,
          signalKey: 'health_stress',
          headline: '資金ストレス局面のセルフケア',
          detail: 'CHOより: お金の決断が続く時期。高額判断は睡眠を確保した朝に回し、'
              '衝動的なリボ・追加借入を避ける。',
        ),
      );
    }

    // ── CEO: 複数部署クリティカル時の優先順位裁定(統合 = 反 Motion の核) ──
    final financialCritical =
        actions.where((a) => a.severity == AdvisorySeverity.critical).length;
    if (financialCritical >= 2) {
      actions.add(
        const AdvisoryAction(
          department: AdvisoryDepartment.ceo,
          severity: AdvisorySeverity.critical,
          signalKey: 'ceo_priority',
          headline: 'CEO室: 今週の最優先を確定',
          detail: '複数部署がクリティカル。CEO室の裁定: 今週はCFO案件(資金繰り・負債)を'
              '最優先に固定し、他部署はそれを支える動きに限定する。',
        ),
      );
    }

    _sort(actions);

    return AdvisoryBriefing(
      generatedAt: now,
      actions: List<AdvisoryAction>.unmodifiable(actions),
      headline: _headline(actions),
    );
  }

  static AdvisorySeverity _mapDebtSeverity(AssetDebtTrendSeverity s) {
    switch (s) {
      case AssetDebtTrendSeverity.critical:
        return AdvisorySeverity.critical;
      case AssetDebtTrendSeverity.warning:
        return AdvisorySeverity.warning;
      case AssetDebtTrendSeverity.info:
        return AdvisorySeverity.info;
    }
  }

  static String _debtCategoryLabel(AssetDebtTrendCategory c) {
    switch (c) {
      case AssetDebtTrendCategory.negativeAmortization:
        return '利息超過(残高が減らない)';
      case AssetDebtTrendCategory.balanceIncreasing:
        return '残高増加';
      case AssetDebtTrendCategory.slowPayoff:
        return '完済の長期化';
    }
  }

  static int _severityRank(AdvisorySeverity s) {
    switch (s) {
      case AdvisorySeverity.critical:
        return 0;
      case AdvisorySeverity.warning:
        return 1;
      case AdvisorySeverity.info:
        return 2;
    }
  }

  static int _departmentRank(AdvisoryDepartment d) {
    switch (d) {
      case AdvisoryDepartment.ceo:
        return 0;
      case AdvisoryDepartment.cfo:
        return 1;
      case AdvisoryDepartment.cmo:
        return 2;
      case AdvisoryDepartment.cho:
        return 3;
      case AdvisoryDepartment.chro:
        return 4;
      case AdvisoryDepartment.planning:
        return 5;
    }
  }

  static void _sort(List<AdvisoryAction> actions) {
    actions.sort((a, b) {
      final bySeverity =
          _severityRank(a.severity).compareTo(_severityRank(b.severity));
      if (bySeverity != 0) return bySeverity;
      return _departmentRank(a.department)
          .compareTo(_departmentRank(b.department));
    });
  }

  static String _headline(List<AdvisoryAction> actions) {
    if (actions.isEmpty) {
      return '参謀室ブリーフィング: 今月は資金繰り・負債・規律に赤信号なし';
    }
    final critical =
        actions.where((a) => a.severity == AdvisorySeverity.critical).length;
    final warning =
        actions.where((a) => a.severity == AdvisorySeverity.warning).length;
    final depts = actions.map((a) => a.department).toSet().length;
    if (critical > 0) {
      return '参謀室ブリーフィング: クリティカル$critical件 / 参謀$depts部署が対応';
    }
    if (warning > 0) {
      return '参謀室ブリーフィング: 要注意$warning件 / 参謀$depts部署が対応';
    }
    return '参謀室ブリーフィング: 参謀$depts部署が現状を確認済み';
  }
}

/// 金額を「1,234円」形式へ決定的に整形する純関数。
String formatAdvisoryYen(double amount) {
  final rounded = amount.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return '$sign$buffer円';
}
