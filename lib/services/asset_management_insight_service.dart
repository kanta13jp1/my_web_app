import '../models/asset_liability_workbook.dart';
import '../models/daily_todo.dart';
import '../models/user_profile.dart';
import 'asset_debt_discipline_monitor.dart';
import 'asset_debt_trend_analyzer.dart';
import 'asset_management_available_money.dart';
import 'asset_triage_guide_service.dart';

enum AssetManagementInsightActionType {
  missingInput,
  missingPaymentDay,
  missingAnnualRate,
  missingPaymentSource,
  overduePayment,
  upcomingPayment,
  cashShortageRisk,
  emergencyLivingExpense,
  cardBillingConfiguration,
  doubleCountingRisk,
  accountShortfallRisk,
}

enum AssetManagementInsightSeverity { info, warning, critical }

enum AssetManagementInsightWindow { today, week, month }

class AssetManagementInsightActionItem {
  final AssetManagementInsightActionType type;
  final AssetManagementInsightSeverity severity;
  final String title;
  final String description;
  final String? relatedAccountId;
  final DateTime? dueDate;
  final int? paymentDay;
  final String suggestedAction;

  const AssetManagementInsightActionItem({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.relatedAccountId,
    required this.dueDate,
    required this.paymentDay,
    required this.suggestedAction,
  });
}

class AssetManagementAvailableMoneyInsight {
  final AssetManagementInsightWindow window;
  final DateTime startDate;
  final DateTime endDate;
  final double cashLikeTotal;
  final double unpaidPaymentTotal;
  final double unreceivedIncomeTotal;
  final double minimumSafetyBalance;
  final double availableAmount;
  final String summary;

  const AssetManagementAvailableMoneyInsight({
    required this.window,
    required this.startDate,
    required this.endDate,
    required this.cashLikeTotal,
    required this.unpaidPaymentTotal,
    required this.unreceivedIncomeTotal,
    required this.minimumSafetyBalance,
    required this.availableAmount,
    required this.summary,
  });
}

class AssetManagementMovementSuggestion {
  final String fromAccountId;
  final String fromAccountName;
  final String? toAccountId;
  final String? toAccountName;
  final double amount;
  final DateTime? neededBy;
  final String reason;

  const AssetManagementMovementSuggestion({
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.neededBy,
    required this.reason,
  });
}

/// 口座別見込み残高が不足する口座への先読み警告。全体の使用可能額が黒字でも
/// 支払原資口座の割り当て次第で引き落とし失敗が起きるため、不足口座と
/// 「どこからいくら動かせば解消するか」(移動提案) をセットで UI へ渡す。
class AssetManagementAccountShortfallAlert {
  final String accountId;
  final String accountName;

  /// 今後の支払予定・入金予定・保留中の口座移動を反映した見込み残高（負値）。
  final double projectedBalance;

  /// 不足額（正値）。
  final double shortfallAmount;

  /// 不足を解消できる口座移動提案。移動元候補が無い場合は null。
  final AssetManagementMovementSuggestion? transferSuggestion;

  const AssetManagementAccountShortfallAlert({
    required this.accountId,
    required this.accountName,
    required this.projectedBalance,
    required this.shortfallAmount,
    this.transferSuggestion,
  });

  bool get hasTransferSuggestion => transferSuggestion != null;
}

class AssetManagementDeveloperRequest {
  final String title;
  final String description;
  final AssetManagementInsightSeverity severity;
  final List<String> evidence;
  final List<String> implementationSteps;
  final List<String> acceptanceCriteria;
  final List<String> sourceReferences;

  const AssetManagementDeveloperRequest({
    required this.title,
    required this.description,
    required this.severity,
    this.evidence = const <String>[],
    this.implementationSteps = const <String>[],
    this.acceptanceCriteria = const <String>[],
    this.sourceReferences = const <String>[],
  });
}

class AssetManagementImplementationContext {
  final String kind;
  final String title;
  final String path;
  final String summary;
  final String excerpt;
  final String improvementUse;

  const AssetManagementImplementationContext({
    required this.kind,
    required this.title,
    required this.path,
    required this.summary,
    required this.excerpt,
    required this.improvementUse,
  });

  static const List<AssetManagementImplementationContext>
      defaultAssetManagementContexts = <AssetManagementImplementationContext>[
    AssetManagementImplementationContext(
      kind: 'source',
      title: '資産管理ページ UI と Issue 発行導線',
      path: 'lib/pages/asset_management_page.dart',
      summary:
          '資産/負債ボードを描画し、AssetManagementInsightReport を生成してAI要約、アクションアイテム、開発者向け改善提案、GitHub Issue化ボタンを表示する。',
      excerpt:
          '_buildAssetManagementAiAssistantSection(report) がAI資産管理アシスタント全体を描画し、_buildAssetManagementDeveloperRequestList(report.developerRequests) が改善提案を表示する。_submitAssetManagementDeveloperIssue は core-hub の feature_request.submit へ title/description/expected_outcome/category/priority/source/dedupe_key を送る。',
      improvementUse: 'UI改善案では、画面上の表示粒度、Issue本文、重複判定キー、ユーザー操作の導線まで踏み込む。',
    ),
    AssetManagementImplementationContext(
      kind: 'source',
      title: '資産負債ワークブック生成',
      path: 'lib/services/asset_liability_planning_service.dart',
      summary:
          '残高スナップショット、月次支払上書き、支払原資口座、カード請求設定、収入予定、口座移動タスクから AssetLiabilityWorkbook を構築する。',
      excerpt:
          'Workbook には accounts、debtMasterRows、paymentDayRisks、cashflowRows、incomePlans、transferTasks、accountCashflowSummaries、transferSuggestions、cardBillingReview、cardStatementReconciliation、月次支払/未払い/利息/元金見込みなどが集約される。',
      improvementUse:
          'データモデル改善案では、既存Workbookに足すべきフィールド、永続化対象、二重計上リスク、月次サイクルの扱いを具体化する。',
    ),
    AssetManagementImplementationContext(
      kind: 'source',
      title: 'AI資産管理インサイト生成',
      path: 'lib/services/asset_management_insight_service.dart',
      summary: 'Dart側で使用可能額、アクションアイテム、口座移動提案、緊急生活防衛アドバイス、開発者向け改善提案を決定論的に生成する。',
      excerpt:
          'buildReport は _buildActionItems、_buildAvailableMoneyInsight、_buildMovementSuggestions、_buildEmergencyAdvices、_buildDeveloperRequests を呼び、計算値はAIではなくDartを正とする。PromptBuilder は詳細プロンプトを作り、口座名・残高・支払日・利率・月利息・元金返済見込みを渡す。',
      improvementUse:
          'プロンプト改善案では、Dart計算値を真実として扱いつつ、AIには優先順位・UX改善・開発タスク分解を担当させる。',
    ),
    AssetManagementImplementationContext(
      kind: 'source',
      title: 'AI詳細ペイロードと ai-hub 呼び出し',
      path: 'lib/services/asset_management_ai_summary_service.dart',
      summary:
          'AI機能フラグが有効な場合に詳細ペイロードを jsonEncode して ai-hub provider chat へ送信し、失敗時は決定論的要約へフォールバックする。',
      excerpt:
          'buildAiDetailedPayload は user_profile、workbook、available_money、action_inventory、situation cards、movement_suggestions、emergency_advices、developer_requests、guardrails を作る。_buildPrompt は PromptBuilder の本文と詳細ペイロード、出力ルールを結合する。',
      improvementUse:
          'AI出力改善案では、payloadに不足している情報、プロンプトの出力契約、fallback時の表示品質、provider routingの失敗時挙動を具体化する。',
    ),
    AssetManagementImplementationContext(
      kind: 'source',
      title: 'Feature Request Edge Function',
      path: 'supabase/functions/core-hub/index.ts',
      summary:
          'feature_request.existing_issues と feature_request.submit が、資産管理画面からの改善提案をGitHub Issue/WBSへ連携する。',
      excerpt:
          'AssetManagementPage は source=asset_management_developer_request と dedupe_key を渡す。Issue本文の情報量が不足すると、後続の実装者が画面、データ、受け入れ条件を読み直す必要がある。',
      improvementUse:
          '開発者向け提案では、Issue化した瞬間に実装者が着手できる粒度の説明、受け入れ条件、検証コマンド、関連ファイルを含める。',
    ),
    AssetManagementImplementationContext(
      kind: 'doc',
      title: '資産管理WBS計画',
      path: 'docs/asset-management-wbs-plan.md',
      summary: '資産管理機能の計画、優先順位、AI活用、検証観点を管理するドキュメント。',
      excerpt: '改善提案は単なるアイデアではなく、WBS/Issueへ落とせる具体タスク、検証方法、ユーザー価値に結びつける必要がある。',
      improvementUse: '提案の優先順位は、借金増加防止、入力漏れ削減、二重計上防止、月次レビュー自動化を優先する。',
    ),
    AssetManagementImplementationContext(
      kind: 'doc',
      title: 'AIモデル評価計画',
      path: 'docs/asset-management-ai-model-evaluation-plan.md',
      summary: '資産管理AIのモデル評価、プロバイダールーティング、回帰検知、品質確認の計画。',
      excerpt:
          'Provider routing、ai-hub、migrationに触る変更はPRレベルの検証が必要。AI出力は金額計算を行わせず、Dart計算値に基づく助言に限定する。',
      improvementUse: 'AI改善案では、promptの変更だけでなく、評価ケース、回帰テスト、期待出力の日本語品質まで提案する。',
    ),
  ];
}

class AssetManagementEmergencyAdvice {
  final AssetManagementInsightSeverity severity;
  final String title;
  final String description;
  final String suggestedAction;
  final double? amount;

  const AssetManagementEmergencyAdvice({
    required this.severity,
    required this.title,
    required this.description,
    required this.suggestedAction,
    required this.amount,
  });
}

class AssetManagementInsightReport {
  final AssetLiabilityWorkbook workbook;
  final UserProfile? userProfile;
  final List<AssetManagementInsightActionItem> actionItems;
  final AssetManagementAvailableMoneyInsight todayAvailable;
  final AssetManagementAvailableMoneyInsight weekAvailable;
  final AssetManagementAvailableMoneyInsight monthAvailable;
  final List<AssetManagementMovementSuggestion> movementSuggestions;

  /// 口座別見込み残高が不足する口座の先読み警告（不足額の大きい順）。
  final List<AssetManagementAccountShortfallAlert> accountShortfallAlerts;
  final List<AssetManagementEmergencyAdvice> emergencyAdvices;
  final List<AssetManagementDeveloperRequest> developerRequests;
  final List<AssetManagementImplementationContext> implementationContexts;

  /// 月をまたいだ負債トレンド（リボ複利・残高増加・超長期完済）の指摘。
  final List<AssetDebtTrendInsight> debtTrendInsights;

  /// 「借金しない宣言」モニターの月次評価
  /// （カード以外の追加借入ゼロ／新規利用分の25日返済）。null=未評価。
  final AssetDebtDisciplineReport? disciplineReport;

  /// 「まず、これだけ」段階別トリアージ (今日3件まで/今週/今月/専門窓口)。null=未評価。
  final AssetTriagePlan? triagePlan;

  /// 「今日やること」ToDo の日々の実行状況（完遂/繰り越し借金/連続日数）。
  /// null=ToDo 未使用。細木数子AI が金銭の負債と並べて行動へ助言するための入力。
  final DailyTodoDigest? dailyTodoDigest;

  const AssetManagementInsightReport({
    required this.workbook,
    this.userProfile,
    required this.actionItems,
    required this.todayAvailable,
    required this.weekAvailable,
    required this.monthAvailable,
    required this.movementSuggestions,
    this.accountShortfallAlerts =
        const <AssetManagementAccountShortfallAlert>[],
    required this.emergencyAdvices,
    required this.developerRequests,
    this.implementationContexts =
        const <AssetManagementImplementationContext>[],
    this.debtTrendInsights = const <AssetDebtTrendInsight>[],
    this.disciplineReport,
    this.triagePlan,
    this.dailyTodoDigest,
  });

  bool get hasAccountShortfallAlerts => accountShortfallAlerts.isNotEmpty;

  bool get hasDebtTrendInsights => debtTrendInsights.isNotEmpty;

  List<AssetDebtTrendInsight> get criticalDebtTrendInsights {
    return debtTrendInsights
        .where((insight) => insight.severity == AssetDebtTrendSeverity.critical)
        .toList(growable: false);
  }

  bool get hasCriticalActions {
    return actionItems.any(
      (item) => item.severity == AssetManagementInsightSeverity.critical,
    );
  }

  List<AssetManagementInsightActionItem> get criticalActions {
    return actionItems
        .where(
          (item) => item.severity == AssetManagementInsightSeverity.critical,
        )
        .toList(growable: false);
  }
}

class AssetManagementInsightService {
  static const double defaultMinimumSafetyBalance = 10000;
  static const int defaultUpcomingPaymentWarningDays = 3;

  const AssetManagementInsightService();

  AssetManagementInsightReport buildReport({
    required AssetLiabilityWorkbook workbook,
    UserProfile? userProfile,
    List<AssetManagementImplementationContext> implementationContexts =
        AssetManagementImplementationContext.defaultAssetManagementContexts,
    double minimumSafetyBalance = defaultMinimumSafetyBalance,
    int upcomingPaymentWarningDays = defaultUpcomingPaymentWarningDays,
    bool livingExpensePriorityMode = false,
    String? mainAccountId,
    Map<String, double> priorMonthAccountBalances = const <String, double>{},
    AssetDebtTrendAnalyzer debtTrendAnalyzer = const AssetDebtTrendAnalyzer(),
    AssetDebtDisciplineMonitor disciplineMonitor =
        const AssetDebtDisciplineMonitor(),
    AssetTriageGuideService triageGuideService =
        const AssetTriageGuideService(),
    DailyTodoDigest? dailyTodoDigest,
  }) {
    final breakdown = _availableMoneyBreakdown(
      workbook: workbook,
      mainAccountId: mainAccountId,
      minimumSafetyBalance: minimumSafetyBalance,
    );
    final today = _availableInsightFromBreakdown(
      AssetManagementInsightWindow.today,
      breakdown,
      workbook.baseDate,
    );
    final week = _availableInsightFromBreakdown(
      AssetManagementInsightWindow.week,
      breakdown,
      workbook.baseDate,
    );
    final month = _availableInsightFromBreakdown(
      AssetManagementInsightWindow.month,
      breakdown,
      workbook.baseDate,
    );
    final actions = _buildActionItems(
      workbook: workbook,
      upcomingPaymentWarningDays: upcomingPaymentWarningDays,
      minimumSafetyBalance: minimumSafetyBalance,
      todayInsight: today,
      livingExpensePriorityMode: livingExpensePriorityMode,
    );
    final movementSuggestions = _buildMovementSuggestions(
      workbook: workbook,
      windows: <AssetManagementAvailableMoneyInsight>[today, week, month],
      minimumSafetyBalance: minimumSafetyBalance,
    );
    final accountShortfallAlerts = _buildAccountShortfallAlerts(
      workbook: workbook,
      movementSuggestions: movementSuggestions,
    );
    final emergencyAdvices = _buildEmergencyAdvices(
      workbook: workbook,
      today: today,
      week: week,
      month: month,
      movementSuggestions: movementSuggestions,
      accountShortfallAlerts: accountShortfallAlerts,
    );
    final developerRequests = _buildDeveloperRequests(
      workbook: workbook,
      actions: actions,
      movementSuggestions: movementSuggestions,
    );
    final debtTrendInsights = debtTrendAnalyzer.analyze(
      workbook: workbook,
      priorBalancesByAccountId: priorMonthAccountBalances,
    );
    final disciplineReport = disciplineMonitor.evaluate(
      workbook: workbook,
      priorBalancesByAccountId: priorMonthAccountBalances,
      cardUsagePolicies: workbook.cardUsagePolicies,
    );
    final triagePlan = triageGuideService.buildPlan(
      workbook: workbook,
      disciplineReport: disciplineReport,
      todayAvailableAmount: today.availableAmount,
      userProfile: userProfile,
    );

    return AssetManagementInsightReport(
      workbook: workbook,
      userProfile: userProfile,
      actionItems: actions,
      todayAvailable: today,
      weekAvailable: week,
      monthAvailable: month,
      movementSuggestions: movementSuggestions,
      accountShortfallAlerts: accountShortfallAlerts,
      emergencyAdvices: emergencyAdvices,
      developerRequests: developerRequests,
      implementationContexts: implementationContexts,
      debtTrendInsights: debtTrendInsights,
      disciplineReport: disciplineReport,
      triagePlan: triagePlan,
      dailyTodoDigest: dailyTodoDigest,
    );
  }

  List<AssetManagementInsightActionItem> _buildActionItems({
    required AssetLiabilityWorkbook workbook,
    required int upcomingPaymentWarningDays,
    required double minimumSafetyBalance,
    required AssetManagementAvailableMoneyInsight todayInsight,
    required bool livingExpensePriorityMode,
  }) {
    final actions = <AssetManagementInsightActionItem>[];
    final today = _dateOnly(workbook.baseDate);
    final upcomingLimit = today.add(Duration(days: upcomingPaymentWarningDays));
    // 口座別見込み残高 (同口座の未払い・保留中の口座移動を合算済み)。
    // 期限超過の支払可否判定と原資候補の順位付けは、口座別不足バナーと
    // 同じこの数字に揃える (行単位の生残高比較は同一口座の兄弟未払いを
    // 二重取りするため使わない)。cash-like 口座のみ含まれるので、
    // じぶん銀行のように預金と負債が同一 id になる名前でも負債側を拾わない。
    final summariesByAccountId = <String, AssetLiabilityAccountCashflowSummary>{
      for (final summary in workbook.accountCashflowSummaries)
        summary.accountId: summary,
    };
    // 原資未設定の負債に提示する引落口座候補。ページ上部バナーの候補一覧と
    // 同じ順位付け (支払後見込み残高の大きい順) で最有力を 1 件だけ本文に載せる。
    final paymentSourceCandidateSummaries = workbook.accountCashflowSummaries
        .toList()
      ..sort((a, b) => b.projectedBalance.compareTo(a.projectedBalance));

    for (final row in workbook.debtMasterRows) {
      if (row.paymentAmountEstimated && row.isDirectCashflowTarget) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingInput,
            severity: AssetManagementInsightSeverity.info,
            title: '${row.name}の今月支払予定額を確認',
            description: '実請求額が未入力のため、推定最低支払額で資金繰りに入っています。',
            relatedAccountId: row.id,
            dueDate: _paymentDateFor(row, workbook.baseDate),
            paymentDay: row.paymentDay,
            suggestedAction: '請求確定後に今月支払予定額を入力してください。',
          ),
        );
      }
      if (row.paymentDay == null) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingPaymentDay,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.name}の支払日が未入力です',
            description: '支払日がないため、支払日順資金繰りで正しい危険日を判断しにくい状態です。',
            relatedAccountId: row.id,
            dueDate: null,
            paymentDay: null,
            suggestedAction: '契約画面または請求明細で支払日を確認し、負債マスタ（支払日順）の「支払日」欄に入力してください。',
          ),
        );
      }
      if (_needsAnnualRate(row)) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingAnnualRate,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.name}の利率を確認',
            description: 'カードローン・カード系の金利が未入力のため、返済優先度の判断精度が落ちます。',
            relatedAccountId: row.id,
            dueDate: _paymentDateFor(row, workbook.baseDate),
            paymentDay: row.paymentDay,
            suggestedAction: '契約中の年利を確認し、負債マスタへ入力してください。',
          ),
        );
      }
      if (row.isDirectCashflowTarget &&
          !row.paid &&
          (row.paymentSourceAccountId == null ||
              row.paymentSourceAccountId!.trim().isEmpty)) {
        // じぶん銀行のように預金と負債が同一 id になる名前があるため自分自身は除外。
        AssetLiabilityAccountCashflowSummary? candidate;
        for (final summary in paymentSourceCandidateSummaries) {
          if (summary.accountId != row.id) {
            candidate = summary;
            break;
          }
        }
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.missingPaymentSource,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.name}の支払原資口座が未設定です',
            description: 'どの口座から引き落とすか未設定のため、'
                '今月予定${_formatYen(row.scheduledPaymentAmount)}が'
                'どの口座の見込み残高からも差し引かれず、残高不足を先読みできない状態です。',
            relatedAccountId: row.id,
            dueDate: _paymentDateFor(row, workbook.baseDate),
            paymentDay: row.paymentDay,
            suggestedAction: candidate == null
                ? '残高のある現金・預金口座が見つかりません。入金後に'
                    '「支払原資口座の未設定」一覧から引落口座を設定してください。'
                : '候補: ${candidate.accountName}'
                    '（残高 ${_formatYen(candidate.currentBalance)} / 支払後見込み '
                    '${_formatYen(candidate.projectedBalance - row.scheduledPaymentAmount)}）。'
                    '「支払原資口座の未設定」一覧から今月だけ上書き、または既定で設定してください。',
          ),
        );
      }
    }

    for (final row in workbook.cashflowRows.where((row) => row.isPayment)) {
      if (!row.isDirectCashflowTarget || row.paid) {
        continue;
      }
      if (row.overdue) {
        // 期限超過は「いくらを・どうやって」まで具体化する（金額は支払予定額。
        // 残高を延滞額扱いしない、のプロンプト規約と揃える）。
        final overdueDays = today.difference(_dateOnly(row.paymentDate)).inDays;
        final sourceAccountId = row.paymentSourceAccountId?.trim() ?? '';
        final sourceSummary = sourceAccountId.isEmpty
            ? null
            : summariesByAccountId[sourceAccountId];
        final String suggestedAction;
        if (sourceAccountId.isEmpty) {
          suggestedAction = '支払原資口座が未設定です。引落口座を設定したうえで、'
              '振込・口座振替・支払先への連絡のどれで支払うかを確認してください。'
              '支払済みの場合は支払済みチェックを更新してください。';
        } else if (sourceSummary == null) {
          // id は設定済みだが残高一覧に現れない (残高0で除外・口座名変更・
          // じぶん銀行のような負債側 id 等)。「未設定」と断定しない。
          final sourceName = row.paymentSourceAccountName ?? sourceAccountId;
          suggestedAction = '原資口座「$sourceName」の残高を今の資産一覧で確認できません'
              '（残高0か口座名変更の可能性）。残高を入力し直すか、'
              '残高のある口座へ原資設定を変更してから支払ってください。';
        } else if (sourceSummary.projectedBalance >= 0) {
          suggestedAction =
              '${sourceSummary.accountName}の残高${_formatYen(sourceSummary.currentBalance)}で'
              '支払可能です。引落状況を確認し、未処理なら'
              '${_formatYen(row.paymentAmount)}を支払って支払済みチェックを更新してください。';
        } else {
          // 同一口座の未払い・保留中の口座移動を合算した見込み不足
          // (口座別不足バナーと同じ数字) を提示する。
          final shortage = sourceSummary.shortfall;
          suggestedAction = '${sourceSummary.accountName}は同口座の未払い分を含めると見込み残高が'
              '${_formatYen(shortage)}不足します。他口座から${_formatYen(shortage)}以上を'
              '${sourceSummary.accountName}へ移動してから、'
              '${_formatYen(row.paymentAmount)}を支払ってください。';
        }
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.overduePayment,
            severity: AssetManagementInsightSeverity.critical,
            title: '${row.accountName}が期限超過です',
            description: overdueDays <= 0
                ? '本日${row.paymentDate.month}月${row.paymentDate.day}日支払予定の'
                    '${_formatYen(row.paymentAmount)}が未払いです。'
                : '${row.paymentDate.month}月${row.paymentDate.day}日支払予定の'
                    '${_formatYen(row.paymentAmount)}が未払いのまま'
                    '$overdueDays日経過しています。',
            relatedAccountId: row.accountId,
            dueDate: row.paymentDate,
            paymentDay: row.paymentDay,
            suggestedAction: suggestedAction,
          ),
        );
      } else if (!row.paymentDate.isBefore(today) &&
          !row.paymentDate.isAfter(upcomingLimit)) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.upcomingPayment,
            severity: AssetManagementInsightSeverity.warning,
            title: '${row.accountName}の支払日が近づいています',
            description: '${_formatYen(row.paymentAmount)}の支払いが近づいています。',
            relatedAccountId: row.accountId,
            dueDate: row.paymentDate,
            paymentDay: row.paymentDay,
            suggestedAction: '支払原資口座の残高を確認してください。',
          ),
        );
      }
      if (row.riskLevel == AssetLiabilityCashRiskLevel.short) {
        actions.add(
          AssetManagementInsightActionItem(
            type: AssetManagementInsightActionType.cashShortageRisk,
            severity: AssetManagementInsightSeverity.critical,
            title: '${row.accountName}支払い後に資金ショートします',
            description: '支払後手元資金が${_formatYen(row.cashAfterPayment)}になります。',
            relatedAccountId: row.accountId,
            dueDate: row.paymentDate,
            paymentDay: row.paymentDay,
            suggestedAction: '支払い前に口座移動または出金を行ってください。',
          ),
        );
      }
    }

    if (todayInsight.availableAmount < 0) {
      actions.add(
        AssetManagementInsightActionItem(
          type: AssetManagementInsightActionType.emergencyLivingExpense,
          severity: AssetManagementInsightSeverity.critical,
          title: '本日の生活費が不足しています',
          description:
              '本日使用可能額が${_formatYen(todayInsight.availableAmount)}です。水だけで過ごすなど、健康を削る判断はしないでください。',
          relatedAccountId: null,
          dueDate: today,
          paymentDay: today.day,
          suggestedAction:
              '支払いを実行する前に、今日の食費・移動費・医療など最低限の生活費を先に確保し、払えない支払いは支払先へ猶予または分割相談をしてください。',
        ),
      );
    }

    // 口座別見込み残高の不足は、使用可能額(全体)が黒字でも支払原資口座の
    // 割り当て次第で発生する（例: 現金口座だけが引き落とし分に足りない）。
    for (final summary in workbook.shortAccountSummaries) {
      actions.add(
        AssetManagementInsightActionItem(
          type: AssetManagementInsightActionType.accountShortfallRisk,
          severity: AssetManagementInsightSeverity.critical,
          title: '${summary.accountName}の見込み残高が不足します',
          description: '今後の支払予定を差し引いた見込み残高が'
              '${_formatYen(summary.projectedBalance)}となり、'
              '${_formatYen(summary.shortfall)}不足します。',
          relatedAccountId: null,
          dueDate: null,
          paymentDay: null,
          suggestedAction:
              '「口座間移動の提案」から${summary.accountName}への移動タスクを作成し、支払い前に実行してください。',
        ),
      );
    }

    for (final item in workbook.cardBillingReview.needsReviewItems) {
      actions.add(
        AssetManagementInsightActionItem(
          type: AssetManagementInsightActionType.cardBillingConfiguration,
          severity: AssetManagementInsightSeverity.warning,
          title: '${item.accountName}のカード請求設定を確認',
          description: item.alerts.join(' / '),
          relatedAccountId: item.accountId,
          dueDate: item.paymentDay == null
              ? null
              : _paymentDateFromDay(workbook.baseDate, item.paymentDay!),
          paymentDay: item.paymentDay,
          suggestedAction:
              '負債マスタ（支払日順）の「支払い方式」でカード請求に含める設定と請求先カードを確認してください。請求額が0円の月は「今月支払予定額」に0を入力してください。',
        ),
      );
    }

    for (final item in workbook.cardBillingReview.doubleCountingRiskItems) {
      actions.add(
        AssetManagementInsightActionItem(
          type: AssetManagementInsightActionType.doubleCountingRisk,
          severity: AssetManagementInsightSeverity.critical,
          title: '${item.accountName}に二重計上リスクがあります',
          description: '直接支払いとカード請求内訳の両方で計算される可能性があります。',
          relatedAccountId: item.accountId,
          dueDate: item.paymentDay == null
              ? null
              : _paymentDateFromDay(workbook.baseDate, item.paymentDay!),
          paymentDay: item.paymentDay,
          suggestedAction: '支払い方式を直接支払いまたはカード請求に含めるのどちらかへ整理してください。',
        ),
      );
    }

    if (livingExpensePriorityMode) {
      final debtRowsById = <String, AssetLiabilityDebtRow>{
        for (final row in workbook.debtMasterRows) row.id: row,
      };
      actions.sort(
        (a, b) => _compareLivingExpensePriorityActionItems(
          a,
          b,
          debtRowsById: debtRowsById,
          subscriptionFixedCostAccountIds:
              workbook.subscriptionFixedCostAccountIds,
        ),
      );
    } else {
      actions.sort(_compareActionItems);
    }
    return actions;
  }

  AssetManagementAvailableMoneyBreakdown _availableMoneyBreakdown({
    required AssetLiabilityWorkbook workbook,
    required String? mainAccountId,
    required double minimumSafetyBalance,
  }) {
    final today = _dateOnly(workbook.baseDate);
    final payday = AssetManagementAvailableMoney.nextPayday(today);
    final remainingDays = AssetManagementAvailableMoney.remainingDaysToPayday(
      today,
      payday,
    );
    final daysThisWeek = AssetManagementAvailableMoney.daysUntilWeekEnd(
      today,
      remainingDays: remainingDays,
    );
    return AssetManagementAvailableMoneyBreakdown(
      availableAssets: AssetManagementAvailableMoney.availableAssets(
        accounts: workbook.accounts,
        mainAccountId: mainAccountId,
      ),
      unpaidUntilPayday: AssetManagementAvailableMoney.unpaidUntilPayday(
        cashflowRows: workbook.cashflowRows,
        payday: payday,
      ),
      minimumSafetyBalance: minimumSafetyBalance,
      remainingDaysToPayday: remainingDays,
      daysThisWeek: daysThisWeek,
      payday: payday,
    );
  }

  AssetManagementAvailableMoneyInsight _availableInsightFromBreakdown(
    AssetManagementInsightWindow window,
    AssetManagementAvailableMoneyBreakdown breakdown,
    DateTime baseDate,
  ) {
    final start = _dateOnly(baseDate);
    final amount = switch (window) {
      AssetManagementInsightWindow.today => breakdown.todayAvailable,
      AssetManagementInsightWindow.week => breakdown.weekAvailable,
      AssetManagementInsightWindow.month => breakdown.monthAvailable,
    };
    final end = switch (window) {
      AssetManagementInsightWindow.today => start,
      AssetManagementInsightWindow.week => start.add(
          Duration(days: breakdown.daysThisWeek - 1),
        ),
      AssetManagementInsightWindow.month => breakdown.payday,
    };
    return AssetManagementAvailableMoneyInsight(
      window: window,
      startDate: start,
      endDate: end,
      cashLikeTotal: breakdown.availableAssets,
      unpaidPaymentTotal: breakdown.unpaidUntilPayday,
      unreceivedIncomeTotal: 0,
      minimumSafetyBalance: breakdown.minimumSafetyBalance,
      availableAmount: amount,
      summary: _availableSummary(window, amount),
    );
  }

  List<AssetManagementMovementSuggestion> _buildMovementSuggestions({
    required AssetLiabilityWorkbook workbook,
    required List<AssetManagementAvailableMoneyInsight> windows,
    required double minimumSafetyBalance,
  }) {
    final suggestions = <AssetManagementMovementSuggestion>[
      for (final suggestion in workbook.transferSuggestions)
        AssetManagementMovementSuggestion(
          fromAccountId: suggestion.fromAccountId,
          fromAccountName: suggestion.fromAccountName,
          toAccountId: suggestion.toAccountId,
          toAccountName: suggestion.toAccountName,
          amount: suggestion.amount,
          neededBy: suggestion.neededBy,
          reason: '口座別資金繰りで不足が見込まれています。',
        ),
    ];

    final worstWindow = windows
        .where((window) => window.availableAmount < 0)
        .toList()
      ..sort((a, b) => a.availableAmount.compareTo(b.availableAmount));
    if (worstWindow.isEmpty) {
      return _dedupeSuggestions(suggestions);
    }

    var needed = worstWindow.first.availableAmount.abs();
    final donors = workbook.accounts
        .where(
          (account) =>
              account.balance > minimumSafetyBalance &&
              (account.kind == AssetLiabilityAccountKind.cash ||
                  account.kind == AssetLiabilityAccountKind.deposit ||
                  account.kind == AssetLiabilityAccountKind.otherAsset),
        )
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    for (final donor in donors) {
      if (needed <= 0) {
        break;
      }
      final surplus = donor.balance - minimumSafetyBalance;
      if (surplus <= 0) {
        continue;
      }
      final amount = surplus < needed ? surplus : needed;
      if (amount <= 0) {
        continue;
      }
      suggestions.add(
        AssetManagementMovementSuggestion(
          fromAccountId: donor.id,
          fromAccountName: donor.name,
          toAccountId: null,
          toAccountName: null,
          amount: amount,
          neededBy: worstWindow.first.endDate,
          reason: '${_windowLabel(worstWindow.first.window)}の使用可能額が不足しています。',
        ),
      );
      needed -= amount;
    }

    return _dedupeSuggestions(suggestions);
  }

  List<AssetManagementEmergencyAdvice> _buildEmergencyAdvices({
    required AssetLiabilityWorkbook workbook,
    required AssetManagementAvailableMoneyInsight today,
    required AssetManagementAvailableMoneyInsight week,
    required AssetManagementAvailableMoneyInsight month,
    required List<AssetManagementMovementSuggestion> movementSuggestions,
    required List<AssetManagementAccountShortfallAlert> accountShortfallAlerts,
  }) {
    final advices = <AssetManagementEmergencyAdvice>[];

    // 口座別の見込み残高不足は全体ウィンドウが黒字でも起きるため、
    // ウィンドウ不足の有無に関わらず先頭で警告する。
    for (final alert in accountShortfallAlerts.take(3)) {
      final suggestion = alert.transferSuggestion;
      // 期限は提案の neededBy がある場合のみ断言する（無い期限を捏造しない）。
      final deadline = suggestion?.neededBy == null
          ? 'できるだけ早く、'
          : '${_formatDate(suggestion!.neededBy!)}までに';
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.critical,
          title: '${alert.accountName}の残高不足を先に解消してください',
          description: '支払予定を差し引くと${alert.accountName}の見込み残高は'
              '${_formatYen(alert.projectedBalance)}'
              '（${_formatYen(alert.shortfallAmount)}不足）です。'
              'このままでは引き落としに失敗します。',
          suggestedAction: suggestion == null
              ? '入金予定の登録または他口座からの移動で'
                  '${_formatYen(alert.shortfallAmount)}以上を確保してから支払いを実行してください。'
              : '$deadline${suggestion.fromAccountName}から${alert.accountName}へ'
                  '${_formatYen(suggestion.amount)}を移動してください。'
                  '「口座間移動の提案」からタスク化すると見込み残高に反映されます。',
          amount: alert.shortfallAmount,
        ),
      );
    }

    final windows = <AssetManagementAvailableMoneyInsight>[today, week, month]
      ..sort((a, b) => a.availableAmount.compareTo(b.availableAmount));
    final worst = windows.first;
    final hasShortage = windows.any((window) => window.availableAmount < 0);
    if (!hasShortage) {
      return advices;
    }

    final nextIncome = _nextIncomePlan(workbook);
    final shortfall =
        worst.availableAmount < 0 ? worst.availableAmount.abs() : 0.0;

    if (today.availableAmount < 0) {
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.critical,
          title: '今日の食費を先に確保してください',
          description:
              '本日使用可能額が${_formatYen(today.availableAmount)}です。給料日まで水だけで耐える方針は危険です。支払いより先に、今日食べるためのお金を隔離してください。',
          suggestedAction:
              '財布または引落口座とは別の口座に、最低でも今日の食費1,000〜1,500円と移動費を残してください。残せない場合は、家族・知人・自治体窓口・フードバンクへ今日中に相談してください。',
          amount: today.availableAmount.abs(),
        ),
      );
    }

    if (shortfall > 0) {
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.critical,
          title: '払う順番を一度止めて組み替えてください',
          description:
              '${_windowLabel(worst.window)}の不足額は${_formatYen(shortfall)}です。全支払いを予定通り払う前提だと生活費が残りません。',
          suggestedAction:
              '優先順位は「食費・通勤・住居/公共料金の継続」→「期限超過の連絡」→「カード/ローンの猶予・分割相談」です。支払先へ、今日中に支払日変更・最低額変更・一時猶予を相談してください。',
          amount: shortfall,
        ),
      );
    }

    if (movementSuggestions.isNotEmpty) {
      final suggestion = movementSuggestions.first;
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.warning,
          title: '口座移動または出金を先に実行してください',
          description:
              '${suggestion.fromAccountName}から${_formatYen(suggestion.amount)}を動かす候補があります。',
          suggestedAction:
              '支払い前にこの移動を実行し、生活費用の残高を確認してください。移動後も不足する場合は、その支払いは払う前に支払先へ連絡してください。',
          amount: suggestion.amount,
        ),
      );
    }

    if (nextIncome == null) {
      advices.add(
        const AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.warning,
          title: '次の入金予定を登録してください',
          description: '給料日や入金予定が未登録のため、何日分の生活費を守るべきか判断しにくい状態です。',
          suggestedAction:
              '給料日・金額・入金先口座を収入予定に入れてください。登録後、AIアシスタントが給料日までの不足額を再計算します。',
          amount: null,
        ),
      );
    } else {
      advices.add(
        AssetManagementEmergencyAdvice(
          severity: AssetManagementInsightSeverity.info,
          title: '次の入金日までの生活費を分けてください',
          description:
              '次の入金予定は${_formatDate(nextIncome.date)}の${nextIncome.name} ${_formatYen(nextIncome.amount)}です。',
          suggestedAction:
              'この入金日までに必要な食費を先に確保し、残額だけを支払いに回してください。入金前に資金が尽きる場合は支払い猶予の相談を優先してください。',
          amount: nextIncome.amount,
        ),
      );
    }

    advices.add(
      const AssetManagementEmergencyAdvice(
        severity: AssetManagementInsightSeverity.info,
        title: '公的・地域の緊急支援も候補に入れてください',
        description: '食費が確保できない場合は、アプリ内の節約だけではなく外部支援を使う局面です。',
        suggestedAction:
            '自治体の生活困窮者自立支援窓口、社会福祉協議会、フードバンク、緊急小口資金の相談先を今日確認してください。',
        amount: null,
      ),
    );

    return advices;
  }

  /// 口座別見込み残高が不足する口座を不足額の大きい順に並べ、その口座を
  /// 移動先とする口座移動提案（あれば）を紐付けて返す。
  List<AssetManagementAccountShortfallAlert> _buildAccountShortfallAlerts({
    required AssetLiabilityWorkbook workbook,
    required List<AssetManagementMovementSuggestion> movementSuggestions,
  }) {
    final summaries = workbook.shortAccountSummaries
      ..sort((a, b) => b.shortfall.compareTo(a.shortfall));
    return <AssetManagementAccountShortfallAlert>[
      for (final summary in summaries)
        AssetManagementAccountShortfallAlert(
          accountId: summary.accountId,
          accountName: summary.accountName,
          projectedBalance: summary.projectedBalance,
          shortfallAmount: summary.shortfall,
          transferSuggestion: _firstSuggestionForAccount(
            summary.accountId,
            movementSuggestions,
          ),
        ),
    ];
  }

  AssetManagementMovementSuggestion? _firstSuggestionForAccount(
    String accountId,
    List<AssetManagementMovementSuggestion> suggestions,
  ) {
    for (final suggestion in suggestions) {
      if (suggestion.toAccountId == accountId) {
        return suggestion;
      }
    }
    return null;
  }

  AssetLiabilityIncomePlan? _nextIncomePlan(AssetLiabilityWorkbook workbook) {
    final today = _dateOnly(workbook.baseDate);
    final plans = workbook.incomePlans
        .where(
          (plan) =>
              !plan.received &&
              plan.amount > 0 &&
              !_dateOnly(plan.date).isBefore(today),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return plans.isEmpty ? null : plans.first;
  }

  List<AssetManagementDeveloperRequest> _buildDeveloperRequests({
    required AssetLiabilityWorkbook workbook,
    required List<AssetManagementInsightActionItem> actions,
    required List<AssetManagementMovementSuggestion> movementSuggestions,
  }) {
    final requests = <AssetManagementDeveloperRequest>[];
    final estimatedPaymentRows = workbook.debtMasterRows
        .where((row) => row.paymentAmountEstimated)
        .toList(growable: false);
    if (estimatedPaymentRows.isNotEmpty) {
      requests.add(
        AssetManagementDeveloperRequest(
          title: '請求確定額と推定額の差分レビュー導線',
          description:
              '現状では推定最低支払額のまま残っている負債が${estimatedPaymentRows.length}件あり、'
              '請求確定後に「今月支払予定額」「実支払額」「差分理由」をまとめて見直す導線が弱いです。'
              '負債マスタ上部に「請求確定待ち」フィルタと一括レビュー画面を追加し、'
              'カード明細取込結果との差分、前月との差分、支払後残高見込みまで1画面で確定できるようにしてください。',
          severity: AssetManagementInsightSeverity.info,
          evidence: <String>[
            '推定額の負債行: ${estimatedPaymentRows.length}件',
            '対象: ${_joinDebtNames(estimatedPaymentRows)}',
            '今月支払予定合計: ${_formatYen(workbook.monthlyScheduledPaymentTotal)}',
            '今月実支払合計: ${_formatYen(workbook.monthlyActualPaymentTotal)}',
          ],
          implementationSteps: const <String>[
            'AssetManagementPageの負債マスタに「請求確定待ち」フィルタと一括編集モードを追加する。',
            'AssetLiabilityMonthlyStateStoreへ実支払額、差分理由、確認済みフラグを月次キーで保存する。',
            'カード明細取込がある場合はcardStatementReconciliationの差分を同じ画面に表示する。',
            '確認後はdeveloper requestではなく通常アクションアイテムから消えるようにする。',
          ],
          acceptanceCriteria: const <String>[
            '推定額行が1件以上あるとき、請求確定待ち件数と対象名が表示される。',
            '実支払額と差分理由を保存すると、月次再読み込み後も値が復元される。',
            'カード明細と設定内訳に差分がある場合、差分金額が同じレビュー画面に出る。',
          ],
          sourceReferences: const <String>[
            'lib/pages/asset_management_page.dart',
            'lib/services/asset_liability_monthly_state_store.dart',
            'lib/services/asset_liability_planning_service.dart',
          ],
        ),
      );
    }
    final missingSourceActions = actions
        .where(
          (action) =>
              action.type ==
              AssetManagementInsightActionType.missingPaymentSource,
        )
        .toList(growable: false);
    if (missingSourceActions.isNotEmpty) {
      requests.add(
        AssetManagementDeveloperRequest(
          title: '支払原資口座の未設定レビュー',
          description: '現状では支払原資口座が未設定のままでも資金繰り計算へ進めてしまい、'
              'どの口座から引き落とされるか不明な支払いが残ります。'
              '未設定項目だけを抽出するレビュー画面を用意し、候補口座、支払日、支払予定額、'
              '支払後見込み残高を並べて、1クリックで既定値として保存できるようにしてください。',
          severity: AssetManagementInsightSeverity.warning,
          evidence: <String>[
            '支払原資未設定アクション: ${missingSourceActions.length}件',
            '対象: ${missingSourceActions.map((item) => item.title).join('、')}',
            '口座別見込み行: ${workbook.accountCashflowSummaries.length}件',
          ],
          implementationSteps: const <String>[
            '支払原資未設定だけを表示するモーダルまたはセクションを追加する。',
            '候補口座は現金同等資産の残高、支払後見込み残高、安全残高を併記して並べる。',
            '保存時はデフォルト設定と当月上書きのどちらへ反映するかを選べるようにする。',
            '保存後にWorkbookを再構築し、未設定アクションと口座別不足が減ることを確認する。',
          ],
          acceptanceCriteria: const <String>[
            '未設定項目だけを一覧化でき、対象名、支払日、金額、候補口座が同時に見える。',
            '保存後、同じ月の再表示で支払原資口座が復元される。',
            '支払原資の変更で口座別見込み残高と口座移動提案が再計算される。',
          ],
          sourceReferences: const <String>[
            'lib/pages/asset_management_page.dart',
            'lib/services/asset_liability_planning_service.dart',
            'lib/services/asset_liability_monthly_state_store.dart',
          ],
        ),
      );
    }
    if (workbook.cardBillingReview.hasNeedsReviewItems) {
      requests.add(
        AssetManagementDeveloperRequest(
          title: 'カード請求内訳の設定監査',
          description: '現状ではカード請求に含める項目の請求先不整合、明細取込との差分、'
              '直接支払いとの二重計上リスクを別々に確認する必要があります。'
              'カードごとの請求額、設定内訳合計、取込明細合計、差分、対象内訳を1つの監査ビューにまとめ、'
              '請求先未設定や削除済みカードをその場で修正できるようにしてください。',
          severity: AssetManagementInsightSeverity.warning,
          evidence: <String>[
            '確認が必要なカード請求項目: ${workbook.cardBillingReview.needsReviewItems.length}件',
            '請求先未設定項目: ${workbook.cardBillingReview.missingBillingAccountItems.length}件',
            '二重計上リスク: ${workbook.cardBillingReview.doubleCountingRiskItems.length}件',
            '明細取込件数: ${workbook.cardStatementReconciliation.importedLineCount}件',
          ],
          implementationSteps: const <String>[
            'cardBillingReviewとcardStatementReconciliationを統合した「カード請求監査」セクションを追加する。',
            'カードごとに設定内訳合計、取込明細合計、請求額、差分、アラートを表示する。',
            '未設定または削除済みカードはその場で請求先を再選択できるようにする。',
            '直接支払いとカード請求内訳の二重計上候補は保存前に警告する。',
          ],
          acceptanceCriteria: const <String>[
            'カードごとの差分が0円でない場合、差分理由と対象明細が見える。',
            '請求先カード未設定の項目を監査ビューから修正できる。',
            '二重計上リスクの項目は支払い方式を整理するまで警告が残る。',
          ],
          sourceReferences: const <String>[
            'lib/pages/asset_management_page.dart',
            'lib/services/asset_liability_card_statement_import_service.dart',
            'lib/services/asset_liability_planning_service.dart',
          ],
        ),
      );
    }
    if (movementSuggestions.isNotEmpty || workbook.hasAccountShortage) {
      requests.add(
        AssetManagementDeveloperRequest(
          title: '口座間移動タスク管理',
          description: '現状では口座間移動の提案が出ても、実行予定、実行済み、キャンセル理由を月次タスクとして扱いにくいです。'
              '不足口座、移動元候補、必要額、期限、実行後見込み残高を1行にまとめ、'
              '提案からタスク化、完了チェック、翌月への繰越まで管理できるようにしてください。',
          severity: AssetManagementInsightSeverity.warning,
          evidence: <String>[
            '口座移動提案: ${movementSuggestions.length}件',
            '口座不足あり: ${workbook.hasAccountShortage ? 'はい' : 'いいえ'}',
            '口座別見込み行: ${workbook.accountCashflowSummaries.length}件',
          ],
          implementationSteps: const <String>[
            'movementSuggestionsをワンクリックでtransferTasksへ変換するボタンを追加する。',
            'transferTasksに実行日、完了、キャンセル理由、実行後残高メモを保存できるようにする。',
            '完了済みタスクは使用可能額計算で二重に差し引かないことを明示する。',
            '給料日サイクルの切替時に未完了タスクを繰り越すか確認する。',
          ],
          acceptanceCriteria: const <String>[
            '口座移動提案からタスクを作成でき、再読み込み後も残る。',
            'タスク完了後、同じ移動提案が重複表示されない。',
            '未完了タスクは翌給料サイクルに繰り越すか破棄するか選べる。',
          ],
          sourceReferences: const <String>[
            'lib/pages/asset_management_page.dart',
            'lib/services/asset_liability_monthly_state_store.dart',
            'lib/services/asset_management_insight_service.dart',
          ],
        ),
      );
    }
    if (requests.isEmpty) {
      requests.add(
        const AssetManagementDeveloperRequest(
          title: '月次レビュー履歴の強化',
          description:
              '現状ではAI資産管理アシスタントの確認結果、ユーザーの判断、実行した改善アクションを月次履歴へ保存していません。'
              'レビュー完了ログ、AI要約、採用した改善提案、手動メモ、翌月への申し送りを保存できるようにしてください。',
          severity: AssetManagementInsightSeverity.info,
          evidence: <String>[
            '現在のアクションアイテムは少ないため、月次の改善履歴を残す段階です。',
            'AI要約と開発者向け改善提案は表示時点の状態に依存します。',
          ],
          implementationSteps: <String>[
            'monthlyReportsまたは専用履歴にAI要約、開発者向け提案、ユーザーメモを保存する。',
            '保存済みレビューを月別に再表示し、前月との差分を見られるようにする。',
            'レビュー完了時に次回確認日または給料日サイクルへ申し送りを作る。',
          ],
          acceptanceCriteria: <String>[
            'レビュー保存後、同じ月を開くとAI要約とメモが復元される。',
            '前月から改善した項目と残った項目を一覧できる。',
            '保存履歴はGitHub Issue化せずともローカル/DBで確認できる。',
          ],
          sourceReferences: <String>[
            'lib/pages/asset_management_page.dart',
            'lib/services/asset_liability_monthly_report_service.dart',
            'lib/services/asset_management_ai_summary_service.dart',
          ],
        ),
      );
    }
    return requests;
  }

  String _joinDebtNames(List<AssetLiabilityDebtRow> rows) {
    if (rows.isEmpty) {
      return 'なし';
    }
    return rows.take(6).map((row) => row.name).join('、') +
        (rows.length > 6 ? ' ほか${rows.length - 6}件' : '');
  }

  bool _needsAnnualRate(AssetLiabilityDebtRow row) {
    if (row.annualRate > 0) {
      return false;
    }
    // 家賃・通信費など全額支払い型の固定費は利率の概念がないため対象外。
    if (row.fullPaymentEstimate) {
      return false;
    }
    return switch (row.kind) {
      AssetLiabilityAccountKind.cardLoan ||
      AssetLiabilityAccountKind.shoppingDebt ||
      AssetLiabilityAccountKind.creditCard ||
      AssetLiabilityAccountKind.otherLiability =>
        true,
      _ => false,
    };
  }

  List<AssetManagementMovementSuggestion> _dedupeSuggestions(
    List<AssetManagementMovementSuggestion> suggestions,
  ) {
    final seen = <String>{};
    final result = <AssetManagementMovementSuggestion>[];
    for (final suggestion in suggestions) {
      final key =
          '${suggestion.fromAccountId}|${suggestion.toAccountId}|${suggestion.amount.round()}';
      if (seen.add(key)) {
        result.add(suggestion);
      }
    }
    return result;
  }

  int _compareActionItems(
    AssetManagementInsightActionItem a,
    AssetManagementInsightActionItem b,
  ) {
    final severity = _severityRank(
      b.severity,
    ).compareTo(_severityRank(a.severity));
    if (severity != 0) {
      return severity;
    }
    final aDate = a.dueDate ?? DateTime(9999);
    final bDate = b.dueDate ?? DateTime(9999);
    final date = aDate.compareTo(bDate);
    if (date != 0) {
      return date;
    }
    return a.title.compareTo(b.title);
  }

  int _compareLivingExpensePriorityActionItems(
    AssetManagementInsightActionItem a,
    AssetManagementInsightActionItem b, {
    required Map<String, AssetLiabilityDebtRow> debtRowsById,
    required Set<String> subscriptionFixedCostAccountIds,
  }) {
    final aRank = _livingExpensePriorityRank(
      a,
      debtRowsById: debtRowsById,
      subscriptionFixedCostAccountIds: subscriptionFixedCostAccountIds,
    );
    final bRank = _livingExpensePriorityRank(
      b,
      debtRowsById: debtRowsById,
      subscriptionFixedCostAccountIds: subscriptionFixedCostAccountIds,
    );
    final priority = aRank.compareTo(bRank);
    if (priority != 0) {
      return priority;
    }
    // 同じ生活防衛バケット内では、OFF 時と同じ重要度・期日・件名順を維持する。
    return _compareActionItems(a, b);
  }

  int _livingExpensePriorityRank(
    AssetManagementInsightActionItem item, {
    required Map<String, AssetLiabilityDebtRow> debtRowsById,
    required Set<String> subscriptionFixedCostAccountIds,
  }) {
    if (item.type == AssetManagementInsightActionType.emergencyLivingExpense) {
      return 0;
    }

    final relatedId = item.relatedAccountId;
    final relatedRow = relatedId == null ? null : debtRowsById[relatedId];
    final isLifeline = relatedRow != null &&
        relatedRow.fullPaymentEstimate &&
        !relatedRow.paid &&
        relatedRow.scheduledPaymentAmount > 0 &&
        !relatedRow.includedInBillingAccount &&
        !subscriptionFixedCostAccountIds.contains(relatedRow.id);
    if (isLifeline) {
      return 0;
    }

    if (item.type == AssetManagementInsightActionType.overduePayment) {
      return 1;
    }

    final isHighInterestLoan = relatedRow != null &&
        !relatedRow.fullPaymentEstimate &&
        relatedRow.kind == AssetLiabilityAccountKind.cardLoan &&
        relatedRow.annualRate >=
            AssetTriageGuideService.highInterestRateThreshold &&
        relatedRow.balance.abs() > 1 &&
        !relatedRow.paid;
    if (isHighInterestLoan) {
      return 2;
    }

    return 3;
  }

  int _severityRank(AssetManagementInsightSeverity severity) {
    return switch (severity) {
      AssetManagementInsightSeverity.critical => 3,
      AssetManagementInsightSeverity.warning => 2,
      AssetManagementInsightSeverity.info => 1,
    };
  }

  DateTime? _paymentDateFor(AssetLiabilityDebtRow row, DateTime baseDate) {
    if (row.paymentDay == null) {
      return null;
    }
    return _paymentDateFromDay(baseDate, row.paymentDay!);
  }

  DateTime _paymentDateFromDay(DateTime baseDate, int day) {
    final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
    return DateTime(baseDate.year, baseDate.month, day.clamp(1, lastDay));
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _availableSummary(AssetManagementInsightWindow window, double amount) {
    final label = _windowLabel(window);
    if (amount < 0) {
      return '$labelの使用可能額は${_formatYen(amount)}です。支払い前に資金移動を確認してください。';
    }
    return '$labelの使用可能額は${_formatYen(amount)}です。';
  }

  String _windowLabel(AssetManagementInsightWindow window) {
    return switch (window) {
      AssetManagementInsightWindow.today => '本日',
      AssetManagementInsightWindow.week => '今週',
      AssetManagementInsightWindow.month => '今月',
    };
  }

  String _formatYen(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer円';
  }

  String _formatDate(DateTime value) {
    return '${value.month}/${value.day}';
  }
}

class AssetManagementInsightPromptBuilder {
  const AssetManagementInsightPromptBuilder();

  String buildPrompt(AssetManagementInsightReport report) {
    final buffer = StringBuffer()
      ..writeln('あなたは資産管理AIアシスタントです。')
      ..writeln('重要: 金額計算はDart側で計算済みです。数値を再計算せず、説明と優先順位付けだけ行ってください。')
      ..writeln()
      ..writeln('## 使用可能額')
      ..writeln('- 本日: ${_formatAmount(report.todayAvailable.availableAmount)}')
      ..writeln('- 今週: ${_formatAmount(report.weekAvailable.availableAmount)}')
      ..writeln('- 今月: ${_formatAmount(report.monthAvailable.availableAmount)}')
      ..writeln()
      ..writeln('## アクションアイテム');
    if (report.actionItems.isEmpty) {
      buffer.writeln('- 重要なアクションはありません。');
    } else {
      for (final item in report.actionItems.take(12)) {
        buffer.writeln(
          '- [${item.severity.name}] ${item.title}: ${item.suggestedAction}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 緊急生活防衛アドバイス');
    if (report.emergencyAdvices.isEmpty) {
      buffer.writeln('- 緊急の生活費不足アドバイスはありません。');
    } else {
      for (final advice in report.emergencyAdvices.take(6)) {
        buffer.writeln(
          '- [${advice.severity.name}] ${advice.title}: ${advice.suggestedAction}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 口座移動/出金提案');
    if (report.movementSuggestions.isEmpty) {
      buffer.writeln('- 現時点で提案はありません。');
    } else {
      for (final suggestion in report.movementSuggestions.take(8)) {
        buffer.writeln(
          '- ${suggestion.fromAccountName}から${_formatAmount(suggestion.amount)}: ${suggestion.reason}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 開発者向け改善提案');
    for (final request in report.developerRequests.take(8)) {
      buffer.writeln('- ${request.title}: ${request.description}');
    }
    return buffer.toString();
  }

  String buildRedactedPrompt(AssetManagementInsightReport report) {
    return buildDetailedAdvicePrompt(report);
  }

  String buildDetailedAdvicePrompt(
    AssetManagementInsightReport report, {
    Map<String, Map<String, dynamic>> existingDeveloperIssuesByTitle =
        const <String, Map<String, dynamic>>{},
  }) {
    final severityCounts = _countBy(
      report.actionItems.map((item) => item.severity.name),
    );
    final typeCounts = _countBy(
      report.actionItems.map((item) => item.type.name),
    );
    final emergencyCounts = _countBy(
      report.emergencyAdvices.map((item) => item.severity.name),
    );
    final developerCounts = _countBy(
      report.developerRequests.map((item) => item.severity.name),
    );
    final workbook = report.workbook;
    final completedOneShotCardNames = workbook.currentDebtRows
        .where(
          (row) => workbook.cardUsagePolicies[row.id]?.enforceOneShot == true,
        )
        .map((row) => row.name)
        .toSet()
        .join('、');
    final buffer = StringBuffer()
      ..writeln('あなたは「細木数子」を彷彿とさせる、ズバズバ断言型の資産管理アシスタントです。')
      ..writeln(
        '役割: 厳しめ、でも本質的には愛情のある生活再建メンターとして、ユーザーの資産・負債・支払予定・利息から個別事情を読み取り、'
        '曖昧な一般論ではなく「あんたは今これを先にやるのよ」と言い切ってください。',
      )
      ..writeln(
        '口調: 「いい？」「あんたね」「ここははっきり言うわよ」「〜なのよ」を使い、少し怖いくらいハッキリ言う。'
        '人生経験豊富な姐御感、時々笑える毒舌、悪いことも包み隠さないが、最後は前向きに導いてください。',
      )
      ..writeln(
        '占いスタイル: 四柱推命・六星占術風の運命周期・宿命・性格分析のような語り口を、お金の流れ、仕事運、生活習慣、今後3〜5年の立て直し方に重ねてください。',
      )
      ..writeln(
        '重要: 金額計算はDart側で完了しています。下記の詳細データを正として、口座名・残高・支払日・支払額・利率・月利息・負債割合を具体的に引用してください。'
        '再計算する場合は「概算」と明記し、Dart計算値と矛盾する断定はしないでください。',
      )
      ..writeln(
        'リボ払いカードの扱い: 返済予定額は「既存残高への最低返済額＋当月の新規利用額」で、'
        '返済日は毎月25日です。取込明細がある場合はその合計を新規利用額として全額上乗せします。'
        '既存残高の一括返済は手元資金を圧迫するため要求・最優先化しないでください。',
      )
      ..writeln(
        '新規利用分を全額返済する設定記録: ${completedOneShotCardNames.isEmpty ? 'なし' : completedOneShotCardNames}。'
        '記録済みカードには、残高一括返済やリボ/分割設定の即時解除を促さず、25日の返済予定と'
        '既存残高を圧縮する最低返済額だけを提示してください。',
      )
      ..writeln(
        '支払済みの扱い: 「支払済み:はい」または「期限超過:いいえ」の負債・支払いは、今月分の支払いが'
        '完了済みです。これらを「未払い」「滞納」「期限超過」「延滞」「今すぐ払え」「期限を過ぎている」等として'
        '指摘・督促してはいけません。支払済みの負債は「今月の支払いと利息」での利息・元金の説明にのみ用い、'
        '未払い合計・期限超過・今日中に払うべき支払いの文脈からは必ず除外してください。'
        '「支払日別リスク」に載っていない負債は期限超過ではありません。',
      )
      ..writeln(
        '受取済み収入の扱い: 「受取済み:はい」または received が true の給与・入金予定は'
        '入金完了済みです。これらを「未受取」「期限超過」「未入金」として督促・指摘してはいけません。',
      )
      ..writeln(
        '支払予定額の優先: 各負債の今月支払うべき額には、機械的な推定最低支払額ではなく'
        '「今月支払予定額（約定返済額/手入力額）」を採用してください。',
      )
      ..writeln(
        '解約済みサブスクの扱い: 金額が0円、または解約済み（disabled/canceled）のサブスクリプションは'
        '「サブスク地獄」「無駄な固定費」「未払い支出」として言及してはいけません。'
        '現在アクティブなサブスクリプションのみを固定費削減の対象として助言してください。',
      )
      ..writeln(
        '金利・残高の正確性: 各負債の年利（年利15.00%等）や残高（-7,519,280円等）は、過去の記憶や'
        '一般的な貸金金利（18.0%）で推測せず、必ず「総合サマリー」「負債マスタ詳細」に記載されている確定値を'
        'そのまま引用してください。',
      )
      ..writeln(
        '残高と支払額の区別: 各負債の「残高」は総借入残高であり、今月の延滞額・今月や今日に'
        '支払うべき額ではありません。「期限超過」「延滞」「今月/今日払うべき額」「不足額」を述べるときは、'
        '必ず月次の「支払額」「推定最低支払額」または「支払日別リスク」の金額を使い、'
        '「残高」を延滞額・今月の支払額として並べてはいけません。残高は「総借入残高」「負債総額」'
        'としてのみ言及してください。特に「8. 最後にズバッと総評」で、残高の数値を'
        '期限超過・延滞・今月支払う額のリストとして提示しないでください。',
      )
      ..writeln(
        '開発者向け改善提案: 現実装コンテキスト、関連ソース、候補タスク、根拠、実装手順、受け入れ条件を使い、'
        '抽象論ではなく「どのファイルをどう変えるか」「どう検証するか」「何ができれば完了か」まで具体的に書いてください。',
      )
      ..writeln('出力は必ず日本語だけにしてください。見出し、ラベル、箇条書きも日本語にしてください。')
      ..writeln(
        '回答は「1. 宿命・本質」「2. 性格の怖いほど当たる特徴」「3. 仕事・お金」「4. 今月の支払いと利息」「5. 今後3〜5年の運気と借金圧縮」「6. 人生で気をつけること」「7. 開発者向け改善提案」「8. 最後にズバッと総評」の順にしてください。',
      )
      ..writeln(
        '「7. 開発者向け改善提案」では、各提案ごとに「現状の痛み」「根拠データ」「変更ファイル」「実装手順」「受け入れ条件」「テスト/確認コマンド」「リスク」を必ず書いてください。',
      )
      ..writeln(
        '「4. 今月の支払いと利息」と「5. 今後3〜5年の運気と借金圧縮」では、下記「今月の問題点と翌月の改善（負債トレンド）」を最優先で扱ってください。'
        '特にリボ払いで返済額が利息以下の負債、前月比で利用残高が増えた負債は、'
        '「今月いくら増えたか」「このままだと何年で完済か/一生終わらないか」「翌月いくら返済すべきか（具体額）」を断言してください。'
        '該当データが無い月だけ、そのカテゴリには触れなくて構いません。',
      )
      ..writeln(
        '下記「借金しない宣言モニター」は本人の固い誓約です。違反（カード以外の追加借入・新規利用分の25日返済不足）があれば、'
        'どの口座でいくらかを具体的に挙げ、「次はこうする」を断言してください。'
        '逆に両誓約を守れている月は、必ず明確に褒めて継続を後押ししてください（締めの総評でも触れる）。',
      )
      ..writeln()
      ..writeln('## 総合サマリー')
      ..writeln('- 基準日: ${_formatDate(workbook.baseDate)}')
      ..writeln('- 現金同等資産: ${_formatAmount(workbook.cashLikeTotal)}')
      ..writeln('- 資産合計: ${_formatAmount(workbook.positiveAssetTotal)}')
      ..writeln('- 負債合計: ${_formatAmount(workbook.liabilityTotal)}')
      ..writeln('- 純資産: ${_formatAmount(workbook.netWorth)}')
      ..writeln('- 負債/資産比率: ${_formatPercent(workbook.debtToAssetRatio)}')
      ..writeln('- 上位4負債の集中度: ${_formatPercent(workbook.topFourDebtShare)}')
      ..writeln(
        '- 今月最低支払推定合計: ${_formatAmount(workbook.monthlyMinimumPaymentEstimateTotal)}',
      )
      ..writeln(
        '- 今月支払予定合計: ${_formatAmount(workbook.monthlyScheduledPaymentTotal)}',
      )
      ..writeln(
        '- 今月未払い合計: ${_formatAmount(workbook.monthlyUnpaidPaymentTotal)}',
      )
      ..writeln(
        '- 今月実支払合計: ${_formatAmount(workbook.monthlyActualPaymentTotal)}',
      )
      ..writeln(
        '- 今月未受取入金合計: ${_formatAmount(workbook.monthlyUnreceivedIncomeTotal)}',
      )
      ..writeln(
        '- 支払後見込み現金: ${_formatAmount(workbook.cashAfterScheduledPayments)}',
      )
      ..writeln()
      ..writeln('## プロフィール詳細')
      ..write(_profileLines(report.userProfile))
      ..writeln()
      ..writeln('## 使用可能額の状態')
      ..writeln('- 本日: ${_availabilityBand(report.todayAvailable)}')
      ..writeln('- 今週: ${_availabilityBand(report.weekAvailable)}')
      ..writeln('- 今月: ${_availabilityBand(report.monthAvailable)}')
      ..writeln()
      ..writeln('## 口座一覧')
      ..write(_accountLines(workbook))
      ..writeln()
      ..writeln('## 負債マスタ詳細')
      ..write(_debtMasterLines(workbook))
      ..writeln()
      ..writeln('## 支払日別リスク')
      ..write(_paymentDayRiskLines(workbook))
      ..writeln()
      ..writeln('## 今月キャッシュフロー')
      ..write(_cashflowLines(workbook))
      ..writeln()
      ..writeln('## 収入予定と口座移動')
      ..write(_incomeAndTransferLines(workbook))
      ..writeln()
      ..writeln('## カード請求内訳と照合')
      ..write(_cardBillingLines(workbook))
      ..writeln()
      ..writeln('## 今月の問題点と翌月の改善（負債トレンド）')
      ..write(_debtTrendLines(report))
      ..writeln()
      ..writeln('## 借金しない宣言モニター（カード以外の追加借入ゼロ／新規利用分の25日返済）')
      ..write(_disciplineLines(report))
      ..writeln()
      ..writeln('## 今日やることトリアージ（Dart計算・この順番のまま提示すること）')
      ..write(_triageLines(report))
      ..writeln()
      ..writeln('## アクション件数')
      ..writeln('- 合計: ${report.actionItems.length}')
      ..writeln('- 重要度別: ${_formatCounts(severityCounts)}')
      ..writeln('- 種別: ${_formatCounts(typeCounts)}')
      ..writeln()
      ..writeln('## 個別事情カード')
      ..write(_redactedSituationCards(report))
      ..writeln()
      ..writeln('## 口座移動と緊急アドバイス')
      ..writeln('- 口座移動・出金提案件数: ${report.movementSuggestions.length}')
      ..writeln('- 緊急生活防衛アドバイス件数: ${report.emergencyAdvices.length}')
      ..writeln('- 緊急アドバイス重要度別: ${_formatCounts(emergencyCounts)}')
      ..writeln()
      ..writeln('## 現実装コンテキスト（ドキュメント・ソースコード抜粋）')
      ..write(_implementationContextLines(report.implementationContexts))
      ..writeln()
      ..writeln('## 開発者向け改善提案候補')
      ..writeln('- 合計: ${report.developerRequests.length}')
      ..writeln('- 重要度別: ${_formatCounts(developerCounts)}')
      ..write(
        _developerRequestLines(
          report.developerRequests,
          existingDeveloperIssuesByTitle: existingDeveloperIssuesByTitle,
        ),
      );
    return buffer.toString();
  }

  String _availabilityBand(AssetManagementAvailableMoneyInsight insight) {
    final amount = insight.availableAmount;
    if (amount < 0) return '不足';
    if (amount < insight.minimumSafetyBalance) return '安全残高未満';
    if (amount < insight.minimumSafetyBalance * 2) return '安全余力が薄い';
    return '余力あり';
  }

  Map<String, int> _countBy(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  String _formatCounts(Map<String, int> counts) {
    if (counts.isEmpty) return 'none';
    final keys = counts.keys.toList(growable: false)..sort();
    return keys.map((key) => '$key=${counts[key]}').join(', ');
  }

  String _accountLines(AssetLiabilityWorkbook workbook) {
    final currentAccounts = workbook.currentAccounts;
    if (currentAccounts.isEmpty) {
      return '- 口座データはありません。\n';
    }
    final buffer = StringBuffer();
    for (final account in currentAccounts) {
      buffer.writeln(
        '- ${account.name} / 種別:${account.kind.name} / 残高:${_formatAmount(account.balance)} / '
        '支払日:${account.paymentDay?.toString() ?? '未設定'} / '
        '年利:${_formatRate(account.annualRate)} / '
        '最低支払率:${_formatRate(account.minimumPaymentRate)} / '
        '最低支払下限:${_formatAmount(account.minimumPaymentFloor)} / '
        '支払い方式:${account.paymentMethodLabel ?? account.paymentMethod.name} / '
        '請求先:${account.billingAccountName ?? 'なし'}',
      );
    }
    return buffer.toString();
  }

  String _profileLines(UserProfile? profile) {
    if (profile == null) {
      return '- プロフィール未連携。生年月日、性別、職業、年収、住所、学歴、職歴、趣味、飲酒、喫煙、好きな食べ物は未入力です。\n';
    }
    final buffer = StringBuffer()
      ..writeln('- 表示名: ${profile.displayName ?? '未入力'}')
      ..writeln('- 生年月日: ${_formatNullableDate(profile.birthDate)}')
      ..writeln('- 性別: ${profile.gender ?? '未入力'}')
      ..writeln('- 職業: ${profile.occupation ?? '未入力'}')
      ..writeln(
        '- 年収: ${profile.annualIncome == null ? '未入力' : _formatAmount(profile.annualIncome!)}',
      )
      ..writeln('- 住所: ${profile.address ?? profile.location ?? '未入力'}')
      ..writeln('- 学歴: ${profile.education ?? '未入力'}')
      ..writeln('- 職歴: ${profile.careerHistory ?? '未入力'}')
      ..writeln('- 趣味: ${profile.hobbies ?? '未入力'}')
      ..writeln('- 飲酒の有無: ${profile.alcoholUse ?? '未入力'}')
      ..writeln('- 喫煙の有無: ${profile.smokingUse ?? '未入力'}')
      ..writeln('- 好きな食べ物: ${profile.favoriteFoods ?? '未入力'}')
      ..writeln('- 自己紹介: ${profile.bio ?? '未入力'}');
    return buffer.toString();
  }

  String _debtMasterLines(AssetLiabilityWorkbook workbook) {
    final currentDebtRows = workbook.currentDebtRows;
    if (currentDebtRows.isEmpty) {
      return '- 負債はありません。\n';
    }
    final buffer = StringBuffer();
    for (final row in currentDebtRows) {
      buffer.writeln(
        '- ${row.name} / 種別:${row.kind.name} / 残高:${_formatAmount(row.balance)} / '
        '負債割合:${_formatPercent(row.liabilityShare)} / '
        '支払日:${row.paymentDay?.toString() ?? '未設定'} / '
        '今月支払予定日:${_formatNullableDate(_paymentDateFor(row, workbook.baseDate))} / '
        '推定最低支払額:${_formatAmount(row.minimumPaymentEstimate)} / '
        '今月支払予定額:${_formatAmount(row.scheduledPaymentAmount)} / '
        '実支払額:${row.actualPaymentAmount == null ? '未入力' : _formatAmount(row.actualPaymentAmount!)} / '
        '差分:${row.paymentDifferenceAmount == null ? '未確定' : _formatAmount(row.paymentDifferenceAmount!)} / '
        '差分理由:${row.paymentDifferenceReason ?? 'なし'} / '
        '年利:${_formatRate(row.annualRate)} / '
        '月利息:${_formatAmount(row.monthlyInterestEstimate)} / '
        '元金返済見込み:${_formatAmount(row.principalPaymentEstimate)} / '
        '支払後残高見込み:${_formatAmount(row.balanceAfterPaymentEstimate)} / '
        '優先度:${row.priorityLabel} / '
        '推定額:${row.paymentAmountEstimated ? 'はい' : 'いいえ'} / '
        '支払済み:${row.paid ? 'はい' : 'いいえ'} / '
        '要対応:${row.requiresAction ? 'はい' : 'いいえ'} / '
        '支払原資:${row.paymentSourceAccountName ?? '未設定'} / '
        '支払い方式:${row.paymentMethodLabel ?? row.paymentMethod.name} / '
        'カード請求先:${row.billingAccountName ?? 'なし'}',
      );
    }
    return buffer.toString();
  }

  String _paymentDayRiskLines(AssetLiabilityWorkbook workbook) {
    if (workbook.paymentDayRisks.isEmpty) {
      return '- 支払日別リスクはありません。\n';
    }
    final buffer = StringBuffer();
    for (final risk in workbook.paymentDayRisks) {
      buffer.writeln(
        '- ${_formatDate(risk.paymentDate)} / 支払日:${risk.paymentDay}日 / '
        '対象:${risk.accountNames.join('、')} / '
        '負債残高合計:${_formatAmount(risk.balanceTotal)} / '
        '推定最低支払合計:${_formatAmount(risk.minimumPaymentEstimateTotal)} / '
        '支払予定合計:${_formatAmount(risk.scheduledPaymentTotal)} / '
        '手入力支払合計:${_formatAmount(risk.manualPaymentTotal)} / '
        '利息見込み合計:${_formatAmount(risk.interestEstimateTotal)} / '
        '区分:${risk.requiresAction ? '要対応' : '確認のみ'} / '
        '状態:${!risk.requiresAction ? '確認のみ' : risk.isPast ? '期限超過' : risk.isToday ? '本日' : '今後'}',
      );
    }
    return buffer.toString();
  }

  String _cashflowLines(AssetLiabilityWorkbook workbook) {
    if (workbook.cashflowRows.isEmpty) {
      return '- キャッシュフロー行はありません。\n';
    }
    final buffer = StringBuffer();
    for (final row in workbook.cashflowRows) {
      buffer.writeln(
        '- ${_formatDate(row.paymentDate)} / ${row.eventType.name} / '
        '項目:${row.accountName} / 金額:${_formatAmount(row.paymentAmount)} / '
        '支払原資:${row.paymentSourceAccountName ?? 'なし'} / '
        '入金先:${row.destinationAccountName ?? 'なし'} / '
        '支払い方式:${row.paymentMethodLabel ?? row.paymentMethod.name} / '
        'カード請求先:${row.billingAccountName ?? 'なし'} / '
        '推定額:${row.paymentAmountEstimated ? 'はい' : 'いいえ'} / '
        '支払済み:${row.paid ? 'はい' : 'いいえ'} / 入金済み:${row.received ? 'はい' : 'いいえ'} / '
        '期限超過:${row.overdue ? 'はい' : 'いいえ'} / '
        '実支払額:${row.actualPaymentAmount == null ? '未入力' : _formatAmount(row.actualPaymentAmount!)} / '
        '差分:${row.paymentDifferenceAmount == null ? '未確定' : _formatAmount(row.paymentDifferenceAmount!)} / '
        '支払前現金:${_formatAmount(row.cashBeforePayment)} / '
        '支払後現金:${_formatAmount(row.cashAfterPayment)} / '
        'リスク:${row.riskLevel.name}',
      );
    }
    return buffer.toString();
  }

  String _incomeAndTransferLines(AssetLiabilityWorkbook workbook) {
    final buffer = StringBuffer();
    if (workbook.incomePlans.isEmpty) {
      buffer.writeln('- 収入予定: なし');
    } else {
      for (final plan in workbook.incomePlans) {
        buffer.writeln(
          '- 収入予定:${plan.name} / 日付:${_formatDate(plan.date)} / '
          '金額:${_formatAmount(plan.amount)} / 入金先:${plan.destinationAccountName ?? '未設定'} / '
          '入金済み:${plan.received ? 'はい' : 'いいえ'}',
        );
      }
    }
    if (workbook.accountCashflowSummaries.isEmpty) {
      buffer.writeln('- 口座別見込み: なし');
    } else {
      for (final summary in workbook.accountCashflowSummaries) {
        buffer.writeln(
          '- 口座別見込み:${summary.accountName} / 現在残高:${_formatAmount(summary.currentBalance)} / '
          '今後支払:${_formatAmount(summary.upcomingPayments)} / 今後入金:${_formatAmount(summary.upcomingIncome)} / '
          '移動入:${_formatAmount(summary.pendingTransferIn)} / 移動出:${_formatAmount(summary.pendingTransferOut)} / '
          '見込み残高:${_formatAmount(summary.projectedBalance)} / リスク:${summary.riskLevel.name}',
        );
      }
    }
    if (workbook.transferSuggestions.isEmpty &&
        workbook.transferTasks.isEmpty) {
      buffer.writeln('- 口座移動: なし');
    } else {
      for (final suggestion in workbook.transferSuggestions) {
        buffer.writeln(
          '- 口座移動提案:${suggestion.fromAccountName} -> ${suggestion.toAccountName} / '
          '金額:${_formatAmount(suggestion.amount)} / 期限:${_formatNullableDate(suggestion.neededBy)}',
        );
      }
      for (final task in workbook.transferTasks) {
        buffer.writeln(
          '- 口座移動タスク:${task.fromAccountName} -> ${task.toAccountName} / '
          '金額:${_formatAmount(task.amount)} / 期限:${_formatNullableDate(task.dueDate)} / '
          '完了:${task.completed ? 'はい' : 'いいえ'} / '
          'キャンセル:${task.canceled ? 'はい' : 'いいえ'}'
          '${task.cancellationReason.trim().isEmpty ? '' : ' / 理由:${task.cancellationReason.trim()}'}',
        );
      }
    }
    return buffer.toString();
  }

  String _cardBillingLines(AssetLiabilityWorkbook workbook) {
    final review = workbook.cardBillingReview;
    final reconciliation = workbook.cardStatementReconciliation;
    final revolvingBillingAccountIds = <String>{
      for (final row in workbook.debtMasterRows)
        if (row.isRevolving) row.id,
    };
    final buffer = StringBuffer();
    if (review.directPaymentItems.isEmpty &&
        review.cardBillingGroups.isEmpty &&
        reconciliation.groups.isEmpty) {
      return '- カード請求内訳はありません。\n';
    }
    for (final item in review.directPaymentItems) {
      buffer.writeln(
        '- 直接支払い:${item.accountName} / 金額:${_formatAmount(item.amount)} / '
        '支払日:${item.paymentDay?.toString() ?? '未設定'} / アラート:${item.alerts.join('、')}',
      );
    }
    for (final group in review.cardBillingGroups) {
      final revolvingNote =
          revolvingBillingAccountIds.contains(group.billingAccountId)
              ? ' / 注記:リボ払いのため下記内訳はリボ残高の紐づけ負債で、今月の請求額ではない'
              : '';
      buffer.writeln(
        '- カード請求グループ:${group.billingAccountName} / 合計:${_formatAmount(group.totalAmount)} / '
        '内訳:${group.items.map((item) => '${item.accountName} ${_formatAmount(item.amount)}').join('、')}$revolvingNote',
      );
    }
    for (final group in reconciliation.groups) {
      final revolving = group.revolvingBilling;
      if (revolving != null) {
        // リボ払いは最低返済額+新規利用額を25日に返す。既存残高は一括返済しない。
        buffer.writeln(
          '- 明細照合(リボ払い):${group.billingAccountName} / '
          '25日返済:${_formatAmount(revolving.billedAmount)}'
          '(=最低返済${_formatAmount(revolving.monthlyAmount)}'
          '+新規利用分全額${_formatAmount(revolving.newUsageAmount)}) / '
          '既存残高:${_formatAmount(revolving.existingBalanceAmount)} / '
          '取込明細合計:${_formatAmount(group.statementLineTotal)} / '
          '注記:既存残高の一括返済は要求せず、新規利用分だけを最低返済額へ上乗せ',
        );
        continue;
      }
      buffer.writeln(
        '- 明細照合:${group.billingAccountName} / 請求額:${_formatAmount(group.billedAmount)} / '
        '設定内訳合計:${_formatAmount(group.configuredDetailTotal)} / '
        '取込明細合計:${_formatAmount(group.statementLineTotal)} / '
        '設定差分:${_formatAmount(group.configuredDifference)} / '
        '明細差分:${_formatAmount(group.statementDifference)} / '
        'アラート:${group.alerts.join('、')}',
      );
    }
    if (reconciliation.unmatchedStatementLines.isNotEmpty) {
      for (final line in reconciliation.unmatchedStatementLines) {
        buffer.writeln(
          '- 未照合明細:${line.billingAccountName ?? line.billingAccountId} / '
          '日付:${_formatNullableDate(line.postedAt)} / 内容:${line.description} / '
          '金額:${_formatAmount(line.amount)}',
        );
      }
    }
    return buffer.toString();
  }

  String _debtTrendLines(AssetManagementInsightReport report) {
    if (report.debtTrendInsights.isEmpty) {
      return '- 月をまたいだ負債の悪化トレンドは検出されていません。'
          '前月比のデータが無い場合は、来月以降の比較のために今月の残高を保存してください。\n';
    }
    final buffer = StringBuffer();
    for (final insight in report.debtTrendInsights) {
      final priorText = insight.priorBalance == null
          ? '前月残高:履歴なし'
          : '前月残高:${_formatAmount(insight.priorBalance!)} / '
              '前月比:${_formatAmount(insight.balanceDelta ?? 0)}';
      final payoffText = insight.estimatedPayoffMonths == null
          ? '完済見込み:この返済額では完済不能'
          : '完済見込み:約${insight.estimatedPayoffMonths}ヶ月';
      buffer
        ..writeln(
          '- ${insight.accountName} / 区分:${_debtTrendCategoryLabel(insight.category)} / '
          '重要度:${insight.severity.name} / 残高:${_formatAmount(insight.currentBalance)} / '
          '$priorText / 月利息:${_formatAmount(insight.monthlyInterest)} / '
          '今月返済:${_formatAmount(insight.scheduledPayment)} / '
          '止血ライン(利息超え):${_formatAmount(insight.interestBreakEvenPayment)} / '
          '24ヶ月完済ライン:${_formatAmount(insight.payoffIn24MonthsPayment)} / '
          '$payoffText',
        )
        ..writeln('  - 問題点: ${insight.problem}')
        ..writeln('  - 翌月アクション: ${insight.nextMonthAction}');
    }
    return buffer.toString();
  }

  String _debtTrendCategoryLabel(AssetDebtTrendCategory category) {
    return switch (category) {
      AssetDebtTrendCategory.negativeAmortization => 'リボ複利(返済が利息以下)',
      AssetDebtTrendCategory.balanceIncreasing => '残高増加(新規利用過多)',
      AssetDebtTrendCategory.slowPayoff => '超長期完済',
    };
  }

  String _disciplineLines(AssetManagementInsightReport report) {
    final discipline = report.disciplineReport;
    if (discipline == null) {
      return '- 規律モニター未評価。\n';
    }
    final buffer = StringBuffer()
      ..writeln(
        '- 誓約①「カード以外の追加借入をしない」: '
        '${discipline.zeroNewBorrowingAchieved ? '達成' : '違反あり'}'
        '${discipline.hasPriorMonthData ? '' : '（前月データ未蓄積のため判定保留）'}',
      )
      ..writeln(
        '- 誓約②「新規利用分は最低返済額へ上乗せし25日に全額返済」: '
        '${discipline.newUsageRepaymentAchieved ? '達成' : '違反あり'}',
      )
      ..writeln('- 今月の新規借入推定合計: ${_formatAmount(discipline.totalNewBorrowing)}')
      ..writeln(
        '- リボ/分割で翌月へ繰り越す残高合計: '
        '${_formatAmount(discipline.totalCarriedOver)}',
      );
    if (discipline.isCompliant) {
      buffer.writeln('- 今月は両誓約を守れています。AIはこの達成を必ず褒め、継続を後押ししてください。');
      return buffer.toString();
    }
    for (final violation in discipline.allViolations) {
      buffer
        ..writeln(
          '- [${violation.severity.name}] '
          '${_disciplineTypeLabel(violation.type)} / ${violation.accountName} / '
          '金額:${_formatAmount(violation.amount)} / '
          '残高:${_formatAmount(violation.currentBalance)}',
        )
        ..writeln('  - 問題点: ${violation.problem}')
        ..writeln('  - 対応: ${violation.action}');
    }
    return buffer.toString();
  }

  String _disciplineTypeLabel(AssetDebtDisciplineViolationType type) {
    return switch (type) {
      AssetDebtDisciplineViolationType.newBorrowing => '追加借入の発生',
      AssetDebtDisciplineViolationType.revolvingCard => '新規利用分の25日返済不足',
    };
  }

  /// 「まず、これだけ」トリアージを AI プロンプトへ渡す。
  /// 混乱している利用者向けの提示順そのものが成果物なので、AI には
  /// 順番の変更や項目の追加をさせない (言い換えのみ許可)。
  String _triageLines(AssetManagementInsightReport report) {
    final plan = report.triagePlan;
    if (plan == null || !plan.hasContent) {
      return '- 今日の緊急対応はありません。現状維持と入力精度の確認を優先してください。\n';
    }
    final buffer = StringBuffer()
      ..writeln('- 免責（利用者にも明示すること）: ${AssetTriagePlan.disclaimer}');
    void writeSteps(String stage, List<AssetTriageStep> steps) {
      if (steps.isEmpty) {
        return;
      }
      buffer.writeln('- $stage:');
      for (var i = 0; i < steps.length; i++) {
        buffer.writeln('  ${i + 1}. ${steps[i].title} — ${steps[i].detail}');
      }
    }

    writeSteps('今日やること（最大3件・この件数以上を今日に割り当てない）', plan.todaySteps);
    if (plan.todaySteps.isNotEmpty) {
      buffer.writeln('  - 締めの一文: ${AssetTriagePlan.todayClosingNote}');
    }
    writeSteps('今週やること', plan.weekSteps);
    writeSteps('今月〜来月やること', plan.monthSteps);
    if (plan.showConsultation && plan.consultationNote != null) {
      buffer.writeln('- 専門窓口（一人で抱えない）: ${plan.consultationNote}');
    }
    return buffer.toString();
  }

  String _redactedSituationCards(AssetManagementInsightReport report) {
    if (report.actionItems.isEmpty && report.emergencyAdvices.isEmpty) {
      return '- 目立つ個別リスクはありません。現状維持と入力精度の確認を優先してください。\n';
    }
    final buffer = StringBuffer();
    for (final item in report.actionItems.take(8)) {
      buffer.writeln(
        '- ${_actionTypeLabel(item.type)} / 項目:${item.title} / '
        '重要度:${item.severity.name} / '
        '期限:${_dueTimingBand(item.dueDate, report.todayAvailable.startDate)} / '
        '次の一手:${item.suggestedAction}',
      );
    }
    for (final advice in report.emergencyAdvices.take(4)) {
      buffer.writeln(
        '- 緊急生活防衛 / 重要度:${advice.severity.name} / '
        '状況:${advice.title} / 次の一手:${advice.suggestedAction}',
      );
    }
    return buffer.toString();
  }

  String _implementationContextLines(
    List<AssetManagementImplementationContext> contexts,
  ) {
    if (contexts.isEmpty) {
      return '- 現実装コンテキストは未指定です。\n';
    }
    final buffer = StringBuffer();
    for (final context in contexts) {
      buffer
        ..writeln('- 種別:${context.kind} / ${context.title}')
        ..writeln('  - パス: ${context.path}')
        ..writeln('  - 要約: ${context.summary}')
        ..writeln('  - 抜粋: ${context.excerpt}')
        ..writeln('  - 改善提案で見る観点: ${context.improvementUse}');
    }
    return buffer.toString();
  }

  String _developerRequestLines(
    List<AssetManagementDeveloperRequest> requests, {
    Map<String, Map<String, dynamic>> existingDeveloperIssuesByTitle =
        const <String, Map<String, dynamic>>{},
  }) {
    if (requests.isEmpty) {
      return '- 開発者向け改善提案候補はありません。\n';
    }
    final buffer = StringBuffer();
    for (final request in requests) {
      final existingIssue = existingDeveloperIssuesByTitle[request.title];
      if (existingIssue != null) {
        // 起票済み候補は echo の材料を渡さず、再掲禁止だけ伝える。
        buffer.writeln(
          '- ${request.title}'
          '（起票済み GitHub Issue #${existingIssue['number'] ?? '-'}。'
          '本文・JSONとも再掲禁止）',
        );
        continue;
      }
      buffer
        ..writeln('- ${request.title}')
        ..writeln('  - 重要度: ${request.severity.name}')
        ..writeln('  - 現状の痛み: ${request.description}');
      if (request.evidence.isNotEmpty) {
        buffer.writeln('  - 根拠データ: ${request.evidence.join(' / ')}');
      }
      if (request.sourceReferences.isNotEmpty) {
        buffer.writeln('  - 変更候補ファイル: ${request.sourceReferences.join(' / ')}');
      }
      if (request.implementationSteps.isNotEmpty) {
        buffer.writeln('  - 実装手順: ${request.implementationSteps.join(' / ')}');
      }
      if (request.acceptanceCriteria.isNotEmpty) {
        buffer.writeln('  - 受け入れ条件: ${request.acceptanceCriteria.join(' / ')}');
      }
    }
    return buffer.toString();
  }

  String _dueTimingBand(DateTime? dueDate, DateTime baseDate) {
    if (dueDate == null) return '不明';
    final base = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(base).inDays;
    if (days < 0) return '期限超過';
    if (days == 0) return '今日';
    if (days <= 3) return '3日以内';
    if (days <= 7) return '7日以内';
    if (due.year == base.year && due.month == base.month) return '今月中';
    return '将来';
  }

  String _actionTypeLabel(AssetManagementInsightActionType type) {
    return switch (type) {
      AssetManagementInsightActionType.missingInput => '請求額の未確定',
      AssetManagementInsightActionType.missingPaymentDay => '支払日の未設定',
      AssetManagementInsightActionType.missingAnnualRate => '金利情報の未設定',
      AssetManagementInsightActionType.missingPaymentSource => '支払原資口座の未設定',
      AssetManagementInsightActionType.overduePayment => '期限超過の未払い',
      AssetManagementInsightActionType.upcomingPayment => '近い支払期限',
      AssetManagementInsightActionType.cashShortageRisk => '支払後の資金ショート',
      AssetManagementInsightActionType.emergencyLivingExpense => '生活費の不足',
      AssetManagementInsightActionType.cardBillingConfiguration => 'カード請求設定の確認',
      AssetManagementInsightActionType.doubleCountingRisk => '二重計上リスク',
      AssetManagementInsightActionType.accountShortfallRisk => '口座別見込み残高の不足',
    };
  }

  String _formatAmount(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer円';
  }

  String _formatDate(DateTime value) {
    return '${value.year}/${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _formatNullableDate(DateTime? value) {
    return value == null ? '未設定' : _formatDate(value);
  }

  String _formatPercent(double value) {
    if (value.isInfinite) return '∞';
    if (value.isNaN) return '不明';
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _formatRate(double value) {
    return _formatPercent(value);
  }

  DateTime? _paymentDateFor(AssetLiabilityDebtRow row, DateTime baseDate) {
    if (row.paymentDay == null) return null;
    final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
    return DateTime(
      baseDate.year,
      baseDate.month,
      row.paymentDay!.clamp(1, lastDay),
    );
  }
}
