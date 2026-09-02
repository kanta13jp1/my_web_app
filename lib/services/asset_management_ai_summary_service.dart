import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/asset_management_ai_analysis_history.dart';
import '../models/asset_liability_workbook.dart';
import '../models/user_profile.dart';
import 'ai_hub_chat_service.dart';
import 'asset_management_ai_provider_router.dart';
import 'asset_management_insight_service.dart';

class AssetManagementAiSummaryFeatureFlag {
  static const String dartDefineName = 'ASSET_MANAGEMENT_AI_SUMMARY_ENABLED';

  static const bool enabled = bool.fromEnvironment(
    dartDefineName,
    defaultValue: false,
  );

  const AssetManagementAiSummaryFeatureFlag._();
}

enum AssetManagementAiSummaryStatus { disabled, aiGenerated, fallback }

class AssetManagementAiSummaryResult {
  final AssetManagementAiSummaryStatus status;
  final String text;
  final String source;
  final String? errorMessage;
  final DateTime generatedAt;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? providerRoute;
  final String? providerChoiceReason;

  /// AIが応答末尾の機械可読ブロックで返した、既知テンプレートと重複しない
  /// 新規改善提案。Issue登録フローへ合流させる。
  final List<AssetManagementDeveloperRequest> aiDeveloperRequests;

  const AssetManagementAiSummaryResult({
    required this.status,
    required this.text,
    required this.source,
    required this.errorMessage,
    required this.generatedAt,
    required this.payload,
    this.providerRoute,
    this.providerChoiceReason,
    this.aiDeveloperRequests = const <AssetManagementDeveloperRequest>[],
  });

  bool get usedExternalAi =>
      status == AssetManagementAiSummaryStatus.aiGenerated;
}

class AssetManagementAiProposalExtraction {
  final String displayText;
  final List<AssetManagementDeveloperRequest> requests;

  const AssetManagementAiProposalExtraction({
    required this.displayText,
    required this.requests,
  });
}

class AssetManagementAiSummaryService {
  // GPT-5 の reasoning トークンや Gemini の thinking トークンも
  // この上限 (maxOutputTokens) を消費するため、本文 (約3,000-4,000トークン) に
  // 思考分の余裕を足す。
  //
  // ⚠️ 実際の上限はサーバ側で決まる: ai-hub の `normalizeMaxTokens` が
  // `min(8192, ...)` にクランプするため、ここに 8192 超を書いても本番では
  // 8192 として扱われる (旧実装の 24000 は「思考に20,000確保」と書かれていたが
  // 本番でそうなったことは一度も無い)。誤解を避けるため実効値の 8192 を明示する。
  // 実測の本文は ~3,000-3,500 トークンなので 8192 でも十分な余裕がある。
  // 上限を実際に引き上げたい場合は ai-hub 側の clamp から変更すること。
  static const int _summaryMaxTokens = 8192;

  final bool _aiEnabled;
  final AiHubChatService _chatService;
  final AssetManagementInsightPromptBuilder _promptBuilder;
  final AssetManagementAiProviderRouter _providerRouter;
  final AssetManagementAiProviderUseCase _useCase;
  final DateTime Function() _now;
  final String? _provider;

  AssetManagementAiSummaryService({
    bool aiEnabled = AssetManagementAiSummaryFeatureFlag.enabled,
    AiHubChatService chatService = const AiHubChatService(),
    AssetManagementInsightPromptBuilder promptBuilder =
        const AssetManagementInsightPromptBuilder(),
    AssetManagementAiProviderRouter providerRouter =
        const AssetManagementAiProviderRouter(),
    AssetManagementAiProviderUseCase useCase =
        AssetManagementAiProviderUseCase.summary,
    DateTime Function()? now,
    String? provider,
  })  : _aiEnabled = aiEnabled,
        _chatService = chatService,
        _promptBuilder = promptBuilder,
        _providerRouter = providerRouter,
        _useCase = useCase,
        _now = now ?? DateTime.now,
        _provider = provider;

  bool get aiEnabled => _aiEnabled;

  Future<AssetManagementAiSummaryResult> generateSummary({
    required AssetManagementInsightReport report,
    List<AssetManagementAiAnalysisHistoryEntry> previousAnalyses =
        const <AssetManagementAiAnalysisHistoryEntry>[],
    Map<String, Map<String, dynamic>> existingDeveloperIssuesByTitle =
        const <String, Map<String, dynamic>>{},
  }) async {
    final payload = buildPayload(report);
    final route = _providerRouter.routeFor(
      useCase: _useCase,
      explicitProvider: _provider,
    );
    final fallback = buildDeterministicSummary(report);
    if (!_aiEnabled) {
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.disabled,
        text: fallback,
        source: 'deterministic fallback / feature flag off',
        errorMessage: null,
        generatedAt: _now(),
        payload: payload,
        providerRoute: route.toLogPayload(),
        providerChoiceReason: route.providerChoiceReason,
      );
    }

    try {
      final detailedPayload = buildAiDetailedPayload(
        report,
        previousAnalyses: previousAnalyses,
        existingDeveloperIssuesByTitle: existingDeveloperIssuesByTitle,
      );
      final prompt = _buildPrompt(
        report: report,
        payload: detailedPayload,
        previousAnalyses: previousAnalyses,
        existingDeveloperIssuesByTitle: existingDeveloperIssuesByTitle,
      );
      final response = route.routingEnabled
          ? await _sendRoutedSummary(prompt: prompt, route: route)
          : _provider == null || _provider == 'auto'
              ? await _chatService.sendAutoChat(
                  message: prompt,
                  tier: 'performance',
                  maxTokens: _summaryMaxTokens,
                  traceId: 'asset-management-ai-summary',
                  providerChoiceReason: route.providerChoiceReason,
                  routingUseCase: route.useCase.id,
                )
              : await _chatService.sendProviderChat(
                  message: prompt,
                  provider: _provider,
                  maxTokens: _summaryMaxTokens,
                  traceId: 'asset-management-ai-summary',
                  providerChoiceReason: route.providerChoiceReason,
                  routingUseCase: route.useCase.id,
                );
      if (!_containsJapaneseText(response.text)) {
        throw const AiHubChatException('AI要約が日本語ではありませんでした');
      }
      final proposals = extractAiDeveloperProposals(response.text);
      // LLMの再掲禁止は確率的にしか守られないため、既知テンプレート・
      // 起票済みIssueと同名の提案は決定論的に除外する。
      final knownTitles = <String>{
        for (final request in report.developerRequests) request.title.trim(),
        for (final title in existingDeveloperIssuesByTitle.keys) title.trim(),
      };
      final novelRequests = proposals.requests
          .where((request) => !knownTitles.contains(request.title.trim()))
          .toList(growable: false);
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.aiGenerated,
        text: proposals.displayText.trim(),
        source: response.source,
        errorMessage: null,
        generatedAt: _now(),
        payload: payload,
        providerRoute: route.toLogPayload(),
        providerChoiceReason: route.providerChoiceReason,
        aiDeveloperRequests: novelRequests,
      );
    } catch (error) {
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.fallback,
        text: fallback,
        source: 'deterministic fallback / ai-hub failed',
        errorMessage: error.toString(),
        generatedAt: _now(),
        payload: payload,
        providerRoute: route.toLogPayload(),
        providerChoiceReason: route.providerChoiceReason,
      );
    }
  }

  AssetManagementAiSummaryResult buildDisabledResult(
    AssetManagementInsightReport report,
  ) {
    final payload = buildPayload(report);
    return AssetManagementAiSummaryResult(
      status: AssetManagementAiSummaryStatus.disabled,
      text: buildDeterministicSummary(report),
      source: 'deterministic fallback / feature flag off',
      errorMessage: null,
      generatedAt: _now(),
      payload: payload,
    );
  }

  AssetManagementAiSummaryResult buildWaitingForAiResult(
    AssetManagementInsightReport report,
  ) {
    final payload = buildPayload(report);
    return AssetManagementAiSummaryResult(
      status: AssetManagementAiSummaryStatus.fallback,
      text: buildDeterministicSummary(report),
      source: 'deterministic fallback / waiting for ai-hub',
      errorMessage: null,
      generatedAt: _now(),
      payload: payload,
    );
  }

  Map<String, dynamic> buildAiSafePayload(AssetManagementInsightReport report) {
    return buildAiDetailedPayload(report);
  }

  Map<String, dynamic> buildAiDetailedPayload(
    AssetManagementInsightReport report, {
    List<AssetManagementAiAnalysisHistoryEntry> previousAnalyses =
        const <AssetManagementAiAnalysisHistoryEntry>[],
    Map<String, Map<String, dynamic>> existingDeveloperIssuesByTitle =
        const <String, Map<String, dynamic>>{},
  }) {
    final workbook = report.workbook;
    return <String, dynamic>{
      'mode': 'exact_financial_detail_for_concrete_advice',
      'user_profile': _profileToDetailedJson(report.userProfile),
      'workbook': _workbookToDetailedJson(workbook),
      'previous_ai_analyses': _previousAnalysesToJson(previousAnalyses),
      'available_money': <String, dynamic>{
        'today': _availableToJson(report.todayAvailable),
        'week': _availableToJson(report.weekAvailable),
        'month': _availableToJson(report.monthAvailable),
      },
      'action_inventory': <String, dynamic>{
        'total': report.actionItems.length,
        'by_type': _countBy(report.actionItems.map((item) => item.type.name)),
        'by_severity': _countBy(
          report.actionItems.map((item) => item.severity.name),
        ),
        'has_due_dates': report.actionItems.any((item) => item.dueDate != null),
        'has_payment_day_metadata': report.actionItems.any(
          (item) => item.paymentDay != null,
        ),
      },
      'personal_context_signals': _buildPersonalContextSignals(report),
      if (report.dailyTodoDigest != null && !report.dailyTodoDigest!.isEmpty)
        'daily_todo': report.dailyTodoDigest!.toAiJson(),
      'priority_situation_cards': report.actionItems
          .map(
            (item) => _actionToDetailedSituationCard(
              item,
              report.todayAvailable.startDate,
            ),
          )
          .toList(growable: false),
      'emergency_situation_cards': report.emergencyAdvices
          .map(_emergencyAdviceToDetailedSituationCard)
          .toList(growable: false),
      'movement_suggestions': <String, dynamic>{
        'count': report.movementSuggestions.length,
        'items': report.movementSuggestions
            .map(
              (suggestion) => <String, dynamic>{
                'from_account_id': suggestion.fromAccountId,
                'from_account_name': suggestion.fromAccountName,
                'to_account_id': suggestion.toAccountId,
                'to_account_name': suggestion.toAccountName,
                'amount': suggestion.amount,
                'needed_by': suggestion.neededBy?.toIso8601String(),
                'reason': suggestion.reason,
              },
            )
            .toList(growable: false),
      },
      'emergency_advices': <String, dynamic>{
        'count': report.emergencyAdvices.length,
        'by_severity': _countBy(
          report.emergencyAdvices.map((advice) => advice.severity.name),
        ),
        'amount_pressure_bands': _countBy(
          report.emergencyAdvices.map(
            (advice) => _amountPressureBand(advice.amount),
          ),
        ),
      },
      'developer_requests': <String, dynamic>{
        'count': report.developerRequests.length,
        'by_severity': _countBy(
          report.developerRequests.map((request) => request.severity.name),
        ),
        'note': '定型生成の既知提案。already_issued=true は既にGitHub Issue起票済みで、'
            'AIはこれらを繰り返さず未起票の新規提案だけを返す。',
        'items': report.developerRequests.map((request) {
          final existingIssue = _existingIssueSummary(
            existingDeveloperIssuesByTitle[request.title],
          );
          if (existingIssue != null) {
            // 起票済み提案は echo の材料にならないよう本文を渡さない。
            return <String, dynamic>{
              'title': request.title,
              'already_issued': true,
              'existing_github_issue': existingIssue,
              'note': '起票済み。本文・JSONブロックとも再掲禁止。',
            };
          }
          return _developerRequestToJson(request)
            ..['already_issued'] = false
            ..['existing_github_issue'] = null;
        }).toList(growable: false),
        'required_output_contract': const <String>[
          '現状の痛み',
          '根拠データ',
          '変更ファイル',
          '実装手順',
          '受け入れ条件',
          'テスト/確認コマンド',
          'リスク',
        ],
      },
      'implementation_context': <String, dynamic>{
        'count': report.implementationContexts.length,
        'items': report.implementationContexts
            .map(_implementationContextToJson)
            .toList(growable: false),
        'purpose': '開発者向け改善提案を、現実装のソースコード/ドキュメントに基づく具体的な実装タスクへ落とすための入力。',
      },
      'guardrails': const <String, dynamic>{
        'calculation_owner': 'dart_service',
        'response_language': 'ja-JP',
        'must_respond_in_japanese': true,
        'must_not_use_english_headings': true,
        'external_ai_receives_exact_account_data': true,
        'external_ai_receives_exact_profile_data': true,
        'external_ai_receives_implementation_context': true,
        'external_ai_receives_previous_analysis_history': true,
        'external_ai_may_reference_exact_money_values': true,
        'external_ai_may_reference_account_names': true,
        'external_ai_may_derive_additional_ratios': true,
        'must_use_supplied_financial_details_as_source_of_truth': true,
        'must_not_invent_unknown_profile_fields': true,
        'must_not_recommend_starvation_or_water_only': true,
        'must_prioritize_food_shelter_health_and_contacting_creditors': true,
        'must_not_flag_paid_items_as_overdue_or_unpaid': true,
      },
    };
  }

  Map<String, dynamic> buildPayload(AssetManagementInsightReport report) {
    return <String, dynamic>{
      'user_profile': _profileToDetailedJson(report.userProfile),
      'workbook': _workbookToDetailedJson(report.workbook),
      'available_money': <String, dynamic>{
        'today': _availableToJson(report.todayAvailable),
        'week': _availableToJson(report.weekAvailable),
        'month': _availableToJson(report.monthAvailable),
      },
      'action_items': report.actionItems
          .map(
            (item) => <String, dynamic>{
              'type': item.type.name,
              'severity': item.severity.name,
              'title': item.title,
              'description': item.description,
              'related_account_id': item.relatedAccountId,
              'due_date': item.dueDate?.toIso8601String(),
              'payment_day': item.paymentDay,
              'suggested_action': item.suggestedAction,
            },
          )
          .toList(growable: false),
      'movement_suggestions': report.movementSuggestions
          .map(
            (suggestion) => <String, dynamic>{
              'from_account_id': suggestion.fromAccountId,
              'from_account_name': suggestion.fromAccountName,
              'to_account_id': suggestion.toAccountId,
              'to_account_name': suggestion.toAccountName,
              'amount': suggestion.amount,
              'needed_by': suggestion.neededBy?.toIso8601String(),
              'reason': suggestion.reason,
            },
          )
          .toList(growable: false),
      'emergency_advices': report.emergencyAdvices
          .map(
            (advice) => <String, dynamic>{
              'severity': advice.severity.name,
              'title': advice.title,
              'description': advice.description,
              'suggested_action': advice.suggestedAction,
              'amount': advice.amount,
            },
          )
          .toList(growable: false),
      'developer_requests': report.developerRequests
          .map(_developerRequestToJson)
          .toList(growable: false),
      'implementation_context': report.implementationContexts
          .map(_implementationContextToJson)
          .toList(growable: false),
      'guardrails': const <String, dynamic>{
        'calculation_owner': 'dart_service',
        'external_ai_receives_exact_account_data': true,
        'external_ai_receives_exact_profile_data': true,
        'external_ai_receives_implementation_context': true,
        'external_ai_may_reference_exact_money_values': true,
        'external_ai_may_reference_account_names': true,
        'external_ai_may_derive_additional_ratios': true,
        'must_use_supplied_financial_details_as_source_of_truth': true,
        'must_not_invent_unknown_profile_fields': true,
        'must_not_recommend_starvation_or_water_only': true,
        'must_prioritize_food_shelter_health_and_contacting_creditors': true,
        'must_not_flag_paid_items_as_overdue_or_unpaid': true,
      },
    };
  }

  String buildRequestFingerprint(AssetManagementInsightReport report) {
    final canonical = jsonEncode(_fingerprintValue(buildPayload(report)));
    return 'sha256:${sha256.convert(utf8.encode(canonical))}';
  }

  String buildDeterministicSummary(AssetManagementInsightReport report) {
    final critical = report.criticalActions.length;
    final actionCount = report.actionItems.length;
    final today = _formatYen(report.todayAvailable.availableAmount);
    final week = _formatYen(report.weekAvailable.availableAmount);
    final month = _formatYen(report.monthAvailable.availableAmount);
    final movement = report.movementSuggestions.isEmpty
        ? '現時点で口座移動・出金提案はありません。'
        : '口座移動・出金提案を${report.movementSuggestions.length}件確認してください。';
    final emergency = report.emergencyAdvices.isEmpty
        ? '緊急の生活費防衛アドバイスはありません。'
        : report.emergencyAdvices
            .take(3)
            .map(
              (advice) => '${advice.title}: ${advice.description} '
                  '${advice.suggestedAction}',
            )
            .join(' ');
    final status = critical > 0 ? '緊急の資金繰り項目があります。' : '緊急度の高い資金繰り項目は検出されていません。';
    return [
      status,
      '要対応: $actionCount件、緊急: $critical件。',
      '使用可能額: 本日 $today、今週 $week、今月 $month。',
      emergency,
      movement,
      '金額はDartルールで計算済みです。AIは要約のみを行います。',
    ].join(' ');
  }

  String _buildPrompt({
    required AssetManagementInsightReport report,
    required Map<String, dynamic> payload,
    List<AssetManagementAiAnalysisHistoryEntry> previousAnalyses =
        const <AssetManagementAiAnalysisHistoryEntry>[],
    Map<String, Map<String, dynamic>> existingDeveloperIssuesByTitle =
        const <String, Map<String, dynamic>>{},
  }) {
    return [
      _promptBuilder.buildDetailedAdvicePrompt(
        report,
        existingDeveloperIssuesByTitle: existingDeveloperIssuesByTitle,
      ),
      '',
      '## AIに渡す詳細ペイロード',
      jsonEncode(payload),
      '',
      if (previousAnalyses.isNotEmpty) ...[
        '## これまでのAI分析履歴（過去スナップショットの数値のみ・現在の事実ではない）',
        jsonEncode(_previousAnalysesToJson(previousAnalyses)),
        '',
      ],
      '出力ルール: FlutterのMarkdownプレビューで表示します。必ずGitHub Flavored Markdownで、## 見出し、- 箇条書き、**強調**を使ってください。見出し、箇条書き、ラベル、本文はすべて自然な日本語にし、英語の見出しや英語ラベルは使わないでください。プロフィールの生年月日、性別、職業、年収、住所、学歴、職歴、趣味、飲酒、喫煙、好きな食べ物を生活背景として引用し、口座名、残高、支払日、推定最低支払額、今月支払予定額、年利、月利息、元金返済見込み、負債割合と結びつけて具体的に助言してください。金額はDart計算値を正として扱い、追加計算は概算と明記してください。細木数子を彷彿とさせる、厳しめで愛情のある断言口調にしてください。曖昧にせず、今日・今週・今月にやることを具体的に言い切ってください。飢える、水だけで耐える、食事を抜くといった健康を害する提案はしないでください。食費、住居、医療、支払先への連絡、公的・地域の緊急支援を優先してください。',
      '現在データ優先ルール: 唯一の「現在の事実」は「AIに渡す詳細ペイロード」とアクションアイテムだけです。previous_ai_analyses（metrics_snapshot）は過去時点のスナップショットで、現在の事実ではありません。履歴に出てくる金額・使用可能額・未払い・期限超過を、現在のものとして断定・督促してはいけません。現在の使用可能額がプラスなら「不足」「マイナス」と言わず、現在のアクションアイテムや支払日別リスクに無い負債、または paid が true の負債を「期限超過」「未払い」と呼ばないでください。受取済み（received: true）の給与・収入を「未受取」「期限超過」として督促してはいけません。今月支払うべき額には推定最低支払額ではなく「今月支払予定額（scheduled_payment_amount）」を用い、解約済みサブスク（金額0円または非アクティブ）を「サブスク地獄」「未払支出」と言及してはいけません。負債の年利（annual_rate）や負債総額は、過去の記憶ではなく必ずペイロード内の確定値（annual_rate, balance）を採用してください。現在値と履歴が矛盾する場合は必ず現在値を採用してください。',
      '履歴利用ルール: previous_ai_analyses がある場合は、各 metrics_snapshot（純資産・未払い合計・使用可能額）の数値と今回の現在値を比較し、「前回比 純資産○円」「未払い合計が△円減/増」のように差分（改善点・悪化点・据え置き点）を述べてください。過去の本文や言い回しを引用・再掲するのではなく、必ず今回の現在値を主語にして書いてください。',
      '日々の行動ルール: daily_todo がある場合は、金銭の負債と同じ熱量で「行動の借金」にも言及してください。carried_over（やらずに繰り越したタスク）は max_carry_over_days が大きいほど厳しく叱り、具体的なタイトルを挙げて「今日こそ片づけなさい」と言い切ってください。active_streak_days が続いていれば必ず褒め、recent_days のこなした実績を根拠に「この調子」と背中を押してください。today_pending が残っていれば寝る前にやり切るよう促してください。daily_todo が無い、または空のときは行動の借金には触れず、金銭面の助言に集中してください（存在しない実績を捏造しないこと）。',
      '完結性ルール: 途中で切れないよう、各章は最大3〜5個の短い箇条書きに圧縮してください。必ず「8. 最後にズバッと総評」まで書き切り、最後の行を「以上。今日やることは、支払い確認、生活費確保、余剰支出停止。この3つよ。」で締めてください。長くなりそうな場合は、負債明細は利息負担の大きい上位5件と合計に絞ってください。',
      '開発者向け改善提案の出力ルール: implementation_context を読んで現状の機能を実際にレビューしてから提案してください。developer_requests は定型生成の既知提案一覧で、already_issued が true のものは既にGitHub Issue起票済みです。本文の「7. 開発者向け改善提案」にも既知提案・起票済み提案やその言い換えを書かないでください。items の title と同一または類似のタイトルは本文にもJSONにも出力禁止です。まだ起票されていない新規の改善提案だけを最大3件返し、新規提案が1件も無い場合は本文には「新規提案なし（既知の提案はすべて起票済みです）」と1行だけ書いてください。各提案は「現状できること（機能レビュー）」「現状の痛み」「根拠データ」「変更ファイル」「実装手順」「受け入れ条件」「テスト/確認コマンド」「リスク」を必ず含め、実装者がそのままGitHub Issueとして着手できる粒度にしてください。現実装にない機能を断言せず、推測は「追加調査」と明記してください。',
      '新規改善提案の機械可読出力ルール: 応答の最後にコードブロックを1つだけ出力してください。コードブロックの開始行は必ず「```json ai-new-proposals」の1行とし、ai-new-proposals を次の行に分けないでください。中身は本文の「7. 開発者向け改善提案」と同じ新規提案を {"title","description","evidence":[],"implementation_steps":[],"acceptance_criteria":[],"source_references":[]} の配列で返し、evidence・implementation_steps・acceptance_criteria・source_references も本文と同じ内容で必ず埋めてください。タイトルは既存Issueと区別できる具体的な日本語にしてください。新規提案がない場合は空配列 [] だけを出力してください。',
    ].join('\n');
  }

  static const String aiProposalsMarker = 'ai-new-proposals';
  static const String aiProposalsFenceHeader = '```json ai-new-proposals';

  /// 応答末尾の機械可読ブロックを取り出し、表示用テキストからは取り除く。
  /// LLMはマーカーをフェンスと同じ行に書かないことがあるため、
  /// 「```json」または「```」の直後にマーカーが続く変形も受け付ける。
  /// ブロックが無い・JSONが壊れている場合は提案なしとして扱う。
  static AssetManagementAiProposalExtraction extractAiDeveloperProposals(
    String text,
  ) {
    final markerIndex = text.lastIndexOf(aiProposalsMarker);
    if (markerIndex < 0) {
      return AssetManagementAiProposalExtraction(
        displayText: text,
        requests: const <AssetManagementDeveloperRequest>[],
      );
    }
    final fenceStart = text.lastIndexOf('```', markerIndex);
    if (fenceStart < 0) {
      return AssetManagementAiProposalExtraction(
        displayText: text,
        requests: const <AssetManagementDeveloperRequest>[],
      );
    }
    final betweenFenceAndMarker =
        text.substring(fenceStart + 3, markerIndex).trim();
    if (betweenFenceAndMarker.isNotEmpty && betweenFenceAndMarker != 'json') {
      // マーカーが本文中の言及で、機械可読ブロックではないケース。
      return AssetManagementAiProposalExtraction(
        displayText: text,
        requests: const <AssetManagementDeveloperRequest>[],
      );
    }
    final bodyStart = markerIndex + aiProposalsMarker.length;
    final closeIndex = text.indexOf('```', bodyStart);
    final rawJson = closeIndex < 0
        ? text.substring(bodyStart)
        : text.substring(bodyStart, closeIndex);
    final blockEnd = closeIndex < 0 ? text.length : closeIndex + 3;
    final displayText =
        (text.substring(0, fenceStart) + text.substring(blockEnd)).trim();
    return AssetManagementAiProposalExtraction(
      displayText: displayText,
      requests: _parseAiProposals(rawJson),
    );
  }

  static List<AssetManagementDeveloperRequest> _parseAiProposals(
    String rawJson,
  ) {
    try {
      final decoded = jsonDecode(rawJson.trim());
      if (decoded is! List) {
        return const <AssetManagementDeveloperRequest>[];
      }
      final requests = <AssetManagementDeveloperRequest>[];
      for (final item in decoded.take(3)) {
        if (item is! Map) {
          continue;
        }
        final title = item['title']?.toString().trim() ?? '';
        final description = item['description']?.toString().trim() ?? '';
        if (title.isEmpty || description.isEmpty) {
          continue;
        }
        requests.add(
          AssetManagementDeveloperRequest(
            title: title,
            description: description,
            severity: AssetManagementInsightSeverity.info,
            evidence: _stringListOf(item['evidence']),
            implementationSteps: _stringListOf(item['implementation_steps']),
            acceptanceCriteria: _stringListOf(item['acceptance_criteria']),
            sourceReferences: _stringListOf(item['source_references']),
          ),
        );
      }
      return requests;
    } catch (_) {
      return const <AssetManagementDeveloperRequest>[];
    }
  }

  static List<String> _stringListOf(Object? source) {
    if (source is! List) {
      return const <String>[];
    }
    final values = <String>[];
    for (final item in source.take(6)) {
      final value = item.toString().trim();
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    return values;
  }

  Map<String, dynamic>? _existingIssueSummary(Map<String, dynamic>? issue) {
    if (issue == null) {
      return null;
    }
    return <String, dynamic>{
      'number': issue['number'],
      'state': issue['state'],
      'title': issue['title'],
      'html_url': issue['html_url'],
    };
  }

  Future<AiHubChatResponse> _sendRoutedSummary({
    required String prompt,
    required AssetManagementAiProviderRouteDecision route,
  }) async {
    Object? lastError;
    for (final candidate in route.candidates) {
      try {
        return await _chatService.sendProviderChat(
          message: prompt,
          provider: candidate.providerId,
          model: candidate.modelId,
          maxTokens: _summaryMaxTokens,
          traceId: 'asset-management-ai-summary',
          providerChoiceReason: route.providerChoiceReason,
          routingUseCase: route.useCase.id,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw AiHubChatException(
      lastError == null
          ? route.localFallbackReason
          : '${route.localFallbackReason}: $lastError',
    );
  }

  Map<String, dynamic> _availableToJson(
    AssetManagementAvailableMoneyInsight insight,
  ) {
    return <String, dynamic>{
      'window': insight.window.name,
      'start_date': insight.startDate.toIso8601String(),
      'end_date': insight.endDate.toIso8601String(),
      'cash_like_total': insight.cashLikeTotal,
      'unpaid_payment_total': insight.unpaidPaymentTotal,
      'unreceived_income_total': insight.unreceivedIncomeTotal,
      'minimum_safety_balance': insight.minimumSafetyBalance,
      'available_amount': insight.availableAmount,
      'summary': insight.summary,
    };
  }

  Map<String, dynamic> _workbookToDetailedJson(
    AssetLiabilityWorkbook workbook,
  ) {
    final revolvingBillingAccountIds = <String>{
      for (final row in workbook.debtMasterRows)
        if (row.isRevolving) row.id,
    };
    return <String, dynamic>{
      'base_date': workbook.baseDate.toIso8601String(),
      'totals': <String, dynamic>{
        'cash_like_total': workbook.cashLikeTotal,
        'securities_total': workbook.securitiesTotal,
        'positive_asset_total': workbook.positiveAssetTotal,
        'liability_total': workbook.liabilityTotal,
        'net_worth': workbook.netWorth,
        'monthly_minimum_payment_estimate_total':
            workbook.monthlyMinimumPaymentEstimateTotal,
        'monthly_scheduled_payment_total':
            workbook.monthlyScheduledPaymentTotal,
        'monthly_scheduled_principal_estimate_total':
            workbook.monthlyScheduledPrincipalEstimateTotal,
        'monthly_scheduled_interest_estimate_total':
            workbook.monthlyScheduledInterestEstimateTotal,
        'monthly_actual_payment_total': workbook.monthlyActualPaymentTotal,
        'monthly_payment_difference_total':
            workbook.monthlyPaymentDifferenceTotal,
        'monthly_unpaid_payment_total': workbook.monthlyUnpaidPaymentTotal,
        'monthly_unreceived_income_total':
            workbook.monthlyUnreceivedIncomeTotal,
        'cash_after_minimum_payments': workbook.cashAfterMinimumPayments,
        'cash_after_scheduled_payments': workbook.cashAfterScheduledPayments,
        'debt_to_asset_ratio': workbook.debtToAssetRatio,
        'top_four_debt_share': workbook.topFourDebtShare,
        'manual_payment_count': workbook.manualPaymentCount,
        'estimated_payment_count': workbook.estimatedPaymentCount,
      },
      'debt_control_review': <String, dynamic>{
        'billing_confirmation_pending_count':
            workbook.billingConfirmationPendingRows.length,
        'billing_confirmation_pending_total':
            workbook.billingConfirmationPendingTotal,
        'billing_confirmation_pending_rows': workbook
            .billingConfirmationPendingRows
            .map((row) => _debtRowToJson(row, workbook.baseDate))
            .toList(growable: false),
        'payment_source_missing_count':
            workbook.paymentSourceMissingRows.length,
        'payment_source_missing_total': workbook.paymentSourceMissingTotal,
        'payment_source_missing_rows': workbook.paymentSourceMissingRows
            .map((row) => _debtRowToJson(row, workbook.baseDate))
            .toList(growable: false),
      },
      'accounts': workbook.accounts.map(_accountToJson).toList(growable: false),
      'debt_master_rows': workbook.debtMasterRows
          .map((row) => _debtRowToJson(row, workbook.baseDate))
          .toList(growable: false),
      // 返済優先順は `debt_master_rows` と同一の行を並べ替えただけなので、
      // 28 フィールドの再シリアライズはやめて「順序」だけを渡す。明細は
      // debt_master_rows を id で引けばよい (プロンプトの重複を削減)。
      'repayment_priority_order': workbook.repaymentPriorityRows
          .map((row) => <String, dynamic>{'id': row.id, 'name': row.name})
          .toList(growable: false),
      'payment_day_risks': workbook.paymentDayRisks
          .map(_paymentDayRiskToJson)
          .toList(growable: false),
      'cashflow_rows':
          workbook.cashflowRows.map(_cashflowRowToJson).toList(growable: false),
      'income_plans':
          workbook.incomePlans.map(_incomePlanToJson).toList(growable: false),
      'transfer_tasks': workbook.transferTasks
          .map(_transferTaskToJson)
          .toList(growable: false),
      'account_cashflow_summaries': workbook.accountCashflowSummaries
          .map(_accountCashflowSummaryToJson)
          .toList(growable: false),
      'transfer_suggestions': workbook.transferSuggestions
          .map(_transferSuggestionToJson)
          .toList(growable: false),
      'card_billing_review': <String, dynamic>{
        'direct_payment_items': workbook.cardBillingReview.directPaymentItems
            .map(_cardReviewItemToJson)
            .toList(growable: false),
        'card_billing_groups': workbook.cardBillingReview.cardBillingGroups
            .map(
              (group) =>
                  _cardBillingGroupToJson(group, revolvingBillingAccountIds),
            )
            .toList(growable: false),
        'missing_billing_account_items': workbook
            .cardBillingReview.missingBillingAccountItems
            .map(_cardReviewItemToJson)
            .toList(growable: false),
        'needs_review_items': workbook.cardBillingReview.needsReviewItems
            .map(_cardReviewItemToJson)
            .toList(growable: false),
        'double_counting_risk_items': workbook
            .cardBillingReview.doubleCountingRiskItems
            .map(_cardReviewItemToJson)
            .toList(growable: false),
      },
      'card_statement_reconciliation': <String, dynamic>{
        'groups': workbook.cardStatementReconciliation.groups
            .map(_cardStatementReconciliationGroupToJson)
            .toList(growable: false),
        'unmatched_statement_lines': workbook
            .cardStatementReconciliation.unmatchedStatementLines
            .map(_statementLineToJson)
            .toList(growable: false),
        'imported_line_count':
            workbook.cardStatementReconciliation.importedLineCount,
        'imported_line_total':
            workbook.cardStatementReconciliation.importedLineTotal,
      },
    };
  }

  Map<String, dynamic>? _profileToDetailedJson(UserProfile? profile) {
    if (profile == null) {
      return null;
    }
    return <String, dynamic>{
      'user_id': profile.userId,
      'display_name': profile.displayName,
      'bio': profile.bio,
      'location': profile.location,
      'birth_date': profile.birthDate?.toIso8601String(),
      'target_death_age': profile.targetDeathAge,
      'disposable_time_ratio': profile.disposableTimeRatio,
      'gender': profile.gender,
      'occupation': profile.occupation,
      'annual_income': profile.annualIncome,
      'address': profile.address,
      'education': profile.education,
      'career_history': profile.careerHistory,
      'hobbies': profile.hobbies,
      'alcohol_use': profile.alcoholUse,
      'smoking_use': profile.smokingUse,
      'favorite_foods': profile.favoriteFoods,
    };
  }

  Map<String, dynamic> _previousAnalysesToJson(
    List<AssetManagementAiAnalysisHistoryEntry> previousAnalyses,
  ) {
    final usefulAnalyses = previousAnalyses
        .where((entry) => entry.hasSummaryText)
        .take(5)
        .toList(growable: false);
    return <String, dynamic>{
      'count': usefulAnalyses.length,
      'items': usefulAnalyses
          .map((entry) => entry.toPromptContextJson())
          .toList(growable: false),
      'usage_rule': 'items は過去時点の数値スナップショット(metrics_snapshot)のみ。現在の事実ではない。'
          '現在値との差分でトレンド(改善点・悪化点)を述べるためだけに使い、履歴の金額・期限超過・未払いを現在として語らない。',
    };
  }

  Map<String, dynamic> _developerRequestToJson(
    AssetManagementDeveloperRequest request,
  ) {
    return <String, dynamic>{
      'title': request.title,
      'description': request.description,
      'severity': request.severity.name,
      'evidence': request.evidence,
      'implementation_steps': request.implementationSteps,
      'acceptance_criteria': request.acceptanceCriteria,
      'source_references': request.sourceReferences,
    };
  }

  Map<String, dynamic> _implementationContextToJson(
    AssetManagementImplementationContext context,
  ) {
    return <String, dynamic>{
      'kind': context.kind,
      'title': context.title,
      'path': context.path,
      'summary': context.summary,
      'excerpt': context.excerpt,
      'improvement_use': context.improvementUse,
    };
  }

  Map<String, dynamic> _accountToJson(AssetLiabilityAccount account) {
    return <String, dynamic>{
      'id': account.id,
      'name': account.name,
      'kind': account.kind.name,
      'balance': account.balance,
      'payment_day': account.paymentDay,
      'payment_source_account_name': account.paymentSourceAccountName,
      'payment_method': account.paymentMethod.name,
      'payment_method_label': account.paymentMethodLabel,
      'payment_method_setting_source': account.paymentMethodSettingSource.name,
      'billing_account_id': account.billingAccountId,
      'billing_account_name': account.billingAccountName,
      'included_in_billing_account': account.includedInBillingAccount,
      'annual_rate': account.annualRate,
      'minimum_payment_rate': account.minimumPaymentRate,
      'minimum_payment_floor': account.minimumPaymentFloor,
      'full_payment_estimate': account.fullPaymentEstimate,
    };
  }

  Map<String, dynamic> _debtRowToJson(
    AssetLiabilityDebtRow row,
    DateTime baseDate,
  ) {
    return <String, dynamic>{
      'id': row.id,
      'name': row.name,
      'kind': row.kind.name,
      'balance': row.balance,
      'liability_share': row.liabilityShare,
      'payment_day': row.paymentDay,
      'scheduled_payment_date': _paymentDateFor(
        row,
        baseDate,
      )?.toIso8601String(),
      'payment_source_account_id': row.paymentSourceAccountId,
      'payment_source_account_name': row.paymentSourceAccountName,
      'payment_method': row.paymentMethod.name,
      'payment_method_label': row.paymentMethodLabel,
      'payment_method_setting_source': row.paymentMethodSettingSource.name,
      'billing_account_id': row.billingAccountId,
      'billing_account_name': row.billingAccountName,
      'included_in_billing_account': row.includedInBillingAccount,
      'is_direct_cashflow_target': row.isDirectCashflowTarget,
      'annual_rate': row.annualRate,
      'minimum_payment_estimate': row.minimumPaymentEstimate,
      'manual_payment_amount': row.manualPaymentAmount,
      'scheduled_payment_amount': row.scheduledPaymentAmount,
      'actual_payment_amount': row.actualPaymentAmount,
      'payment_difference_amount': row.paymentDifferenceAmount,
      'payment_difference_reason': row.paymentDifferenceReason,
      'monthly_interest_estimate': row.monthlyInterestEstimate,
      'principal_payment_estimate': row.principalPaymentEstimate,
      'balance_after_payment_estimate': row.balanceAfterPaymentEstimate,
      'priority_label': row.priorityLabel,
      'payment_amount_estimated': row.paymentAmountEstimated,
      'paid': row.paid,
      'effective_paid_payment_amount': row.effectivePaidPaymentAmount,
    };
  }

  Map<String, dynamic> _paymentDayRiskToJson(
    AssetLiabilityPaymentDayRisk risk,
  ) {
    return <String, dynamic>{
      'payment_day': risk.paymentDay,
      'payment_date': risk.paymentDate.toIso8601String(),
      'account_names': risk.accountNames,
      'balance_total': risk.balanceTotal,
      'minimum_payment_estimate_total': risk.minimumPaymentEstimateTotal,
      'scheduled_payment_total': risk.scheduledPaymentTotal,
      'manual_payment_total': risk.manualPaymentTotal,
      'interest_estimate_total': risk.interestEstimateTotal,
      'manual_payment_count': risk.manualPaymentCount,
      'estimated_payment_count': risk.estimatedPaymentCount,
      'is_past': risk.isPast,
      'is_today': risk.isToday,
      'is_upcoming': risk.isUpcoming,
    };
  }

  Map<String, dynamic> _cashflowRowToJson(AssetLiabilityCashflowRow row) {
    return <String, dynamic>{
      'event_type': row.eventType.name,
      'account_id': row.accountId,
      'account_name': row.accountName,
      'payment_day': row.paymentDay,
      'payment_date': row.paymentDate.toIso8601String(),
      'payment_source_account_id': row.paymentSourceAccountId,
      'payment_source_account_name': row.paymentSourceAccountName,
      'destination_account_id': row.destinationAccountId,
      'destination_account_name': row.destinationAccountName,
      'payment_method': row.paymentMethod.name,
      'payment_method_label': row.paymentMethodLabel,
      'payment_method_setting_source': row.paymentMethodSettingSource.name,
      'billing_account_id': row.billingAccountId,
      'billing_account_name': row.billingAccountName,
      'included_in_billing_account': row.includedInBillingAccount,
      'payment_amount': row.paymentAmount,
      'actual_payment_amount': row.actualPaymentAmount,
      'payment_difference_amount': row.paymentDifferenceAmount,
      'payment_difference_reason': row.paymentDifferenceReason,
      'payment_amount_estimated': row.paymentAmountEstimated,
      'paid': row.paid,
      'received': row.received,
      'overdue': row.overdue,
      'cash_before_payment': row.cashBeforePayment,
      'cash_after_payment': row.cashAfterPayment,
      'risk_level': row.riskLevel.name,
      'is_direct_cashflow_target': row.isDirectCashflowTarget,
    };
  }

  Map<String, dynamic> _incomePlanToJson(AssetLiabilityIncomePlan plan) {
    return <String, dynamic>{
      'id': plan.id,
      'date': plan.date.toIso8601String(),
      'name': plan.name,
      'amount': plan.amount,
      'destination_account_id': plan.destinationAccountId,
      'destination_account_name': plan.destinationAccountName,
      'received': plan.received,
    };
  }

  Map<String, dynamic> _transferTaskToJson(AssetLiabilityTransferTask task) {
    return <String, dynamic>{
      'id': task.id,
      'from_account_id': task.fromAccountId,
      'from_account_name': task.fromAccountName,
      'to_account_id': task.toAccountId,
      'to_account_name': task.toAccountName,
      'amount': task.amount,
      'due_date': task.dueDate?.toIso8601String(),
      'completed': task.completed,
      'completed_at': task.completedAt?.toIso8601String(),
      'completion_memo': task.completionMemo,
      'canceled': task.canceled,
      'canceled_at': task.canceledAt?.toIso8601String(),
      'cancellation_reason': task.cancellationReason,
    };
  }

  Map<String, dynamic> _accountCashflowSummaryToJson(
    AssetLiabilityAccountCashflowSummary summary,
  ) {
    return <String, dynamic>{
      'account_id': summary.accountId,
      'account_name': summary.accountName,
      'current_balance': summary.currentBalance,
      'upcoming_payments': summary.upcomingPayments,
      'upcoming_income': summary.upcomingIncome,
      'pending_transfer_in': summary.pendingTransferIn,
      'pending_transfer_out': summary.pendingTransferOut,
      'projected_balance': summary.projectedBalance,
      'risk_level': summary.riskLevel.name,
      'is_short': summary.isShort,
      'shortfall': summary.shortfall,
    };
  }

  Map<String, dynamic> _transferSuggestionToJson(
    AssetLiabilityTransferSuggestion suggestion,
  ) {
    return <String, dynamic>{
      'from_account_id': suggestion.fromAccountId,
      'from_account_name': suggestion.fromAccountName,
      'to_account_id': suggestion.toAccountId,
      'to_account_name': suggestion.toAccountName,
      'amount': suggestion.amount,
      'needed_by': suggestion.neededBy?.toIso8601String(),
    };
  }

  Map<String, dynamic> _cardReviewItemToJson(
    AssetLiabilityCardBillingReviewItem item,
  ) {
    return <String, dynamic>{
      'account_id': item.accountId,
      'account_name': item.accountName,
      'amount': item.amount,
      'payment_day': item.paymentDay,
      'payment_method': item.paymentMethod.name,
      'payment_method_label': item.paymentMethodLabel,
      'payment_method_setting_source': item.paymentMethodSettingSource.name,
      'billing_account_id': item.billingAccountId,
      'billing_account_name': item.billingAccountName,
      'included_in_billing_account': item.includedInBillingAccount,
      'direct_cashflow_target': item.directCashflowTarget,
      'alerts': item.alerts,
      'needs_review': item.needsReview,
    };
  }

  Map<String, dynamic> _cardBillingGroupToJson(
    AssetLiabilityCardBillingGroup group,
    Set<String> revolvingBillingAccountIds,
  ) {
    final json = <String, dynamic>{
      'billing_account_id': group.billingAccountId,
      'billing_account_name': group.billingAccountName,
      'total_amount': group.totalAmount,
      'items': group.items.map(_cardReviewItemToJson).toList(growable: false),
    };
    if (revolvingBillingAccountIds.contains(group.billingAccountId)) {
      // リボ払いカードに紐づけた負債合計は「リボ残高に含まれる紐づけ負債」であり、
      // その月の請求額(リボ確定額)ではない。AI が請求額と比較して不一致と誤指摘
      // しないよう明示する。
      json['is_revolving_card'] = true;
      json['note'] = 'このカードはリボ払い。下記内訳はリボ残高に含まれる紐づけ負債で、'
          '今月の請求額(リボ確定額)ではない。請求額と比較して不一致と判断しないこと。';
    }
    return json;
  }

  Map<String, dynamic> _cardStatementReconciliationGroupToJson(
    AssetLiabilityCardStatementReconciliationGroup group,
  ) {
    final revolving = group.revolvingBilling;
    if (revolving != null) {
      // リボ払い: 25日の返済予定は最低返済額 + 当月新規利用額。
      // 既存残高は一括返済せず、最低返済額で圧縮する。
      return <String, dynamic>{
        'billing_account_id': group.billingAccountId,
        'billing_account_name': group.billingAccountName,
        'billed_amount': group.billedAmount,
        'is_revolving': true,
        'has_statement_lines': group.hasStatementLines,
        'needs_review': group.needsReview,
        'alerts': group.alerts,
        'reconciliation_status': 'ok_revolving_no_action_needed',
        'revolving_billing': <String, dynamic>{
          'monthly_amount': revolving.monthlyAmount,
          'new_usage_amount': revolving.newUsageAmount,
          'existing_balance_amount': revolving.existingBalanceAmount,
          'payment_day': revolving.paymentDay,
          'balance': revolving.balance,
          'billed_amount': revolving.billedAmount,
        },
        'statement_context': <String, dynamic>{
          'new_usage_this_month_total': group.statementLineTotal,
          'debts_routed_to_card_total': group.configuredDetailTotal,
          'note': '取込明細合計は新規利用額として25日の返済予定へ全額上乗せする。'
              '紐づけ負債合計は参考値で、既存残高の一括返済額ではない。',
        },
        'reconciliation_note': 'リボ払いカード。25日の返済予定=最低返済額+当月新規利用額。'
            '既存残高は一括返済せず最低返済額で圧縮し、新規利用分だけを同月に全額返す。',
        'configured_items': group.configuredItems
            .map(_cardReviewItemToJson)
            .toList(growable: false),
        'statement_lines': group.statementLines
            .map(_statementLineToJson)
            .toList(growable: false),
      };
    }
    return <String, dynamic>{
      'billing_account_id': group.billingAccountId,
      'billing_account_name': group.billingAccountName,
      'billed_amount': group.billedAmount,
      'configured_detail_total': group.configuredDetailTotal,
      'statement_line_total': group.statementLineTotal,
      'configured_difference': group.configuredDifference,
      'statement_difference': group.statementDifference,
      'has_statement_lines': group.hasStatementLines,
      'needs_review': group.needsReview,
      'alerts': group.alerts,
      'is_revolving': false,
      'configured_items': group.configuredItems
          .map(_cardReviewItemToJson)
          .toList(growable: false),
      'statement_lines': group.statementLines
          .map(_statementLineToJson)
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _statementLineToJson(
    AssetLiabilityCardStatementLine line,
  ) {
    return <String, dynamic>{
      'id': line.id,
      'billing_account_id': line.billingAccountId,
      'billing_account_name': line.billingAccountName,
      'posted_at': line.postedAt?.toIso8601String(),
      'description': line.description,
      'amount': line.amount,
    };
  }

  Map<String, int> _countBy(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic> _buildPersonalContextSignals(
    AssetManagementInsightReport report,
  ) {
    return <String, dynamic>{
      'overall_pressure': _overallPressure(report),
      'worst_available_window': _worstAvailableWindow(report).window.name,
      'has_overdue_or_shortage': report.actionItems.any(
        (item) =>
            item.type == AssetManagementInsightActionType.overduePayment ||
            item.type == AssetManagementInsightActionType.cashShortageRisk ||
            item.type ==
                AssetManagementInsightActionType.emergencyLivingExpense,
      ),
      'has_uncertain_debt_inputs': report.actionItems.any(
        (item) =>
            item.type == AssetManagementInsightActionType.missingInput ||
            item.type == AssetManagementInsightActionType.missingAnnualRate ||
            item.type == AssetManagementInsightActionType.missingPaymentDay ||
            item.type == AssetManagementInsightActionType.missingPaymentSource,
      ),
      'has_card_billing_review': report.actionItems.any(
        (item) =>
            item.type ==
                AssetManagementInsightActionType.cardBillingConfiguration ||
            item.type == AssetManagementInsightActionType.doubleCountingRisk,
      ),
      'has_cash_movement_candidate': report.movementSuggestions.isNotEmpty,
      'advice_focus': _adviceFocus(report),
    };
  }

  Map<String, dynamic> _actionToDetailedSituationCard(
    AssetManagementInsightActionItem item,
    DateTime baseDate,
  ) {
    return <String, dynamic>{
      'severity': item.severity.name,
      'type': item.type.name,
      'situation': _actionTypeLabel(item.type),
      'due_timing': _dueTimingBand(item.dueDate, baseDate),
      'payment_day_known': item.paymentDay != null,
      'recommended_next_step': item.suggestedAction,
    };
  }

  Map<String, dynamic> _emergencyAdviceToDetailedSituationCard(
    AssetManagementEmergencyAdvice advice,
  ) {
    return <String, dynamic>{
      'severity': advice.severity.name,
      'situation': advice.title,
      'amount_pressure': _amountPressureBand(advice.amount),
      'recommended_next_step': advice.suggestedAction,
    };
  }

  AssetManagementAvailableMoneyInsight _worstAvailableWindow(
    AssetManagementInsightReport report,
  ) {
    final windows = <AssetManagementAvailableMoneyInsight>[
      report.todayAvailable,
      report.weekAvailable,
      report.monthAvailable,
    ]..sort((a, b) => a.availableAmount.compareTo(b.availableAmount));
    return windows.first;
  }

  String _overallPressure(AssetManagementInsightReport report) {
    if (report.criticalActions.isNotEmpty ||
        _worstAvailableWindow(report).availableAmount < 0) {
      return 'critical_cashflow_pressure';
    }
    if (report.actionItems.any(
      (item) => item.severity == AssetManagementInsightSeverity.warning,
    )) {
      return 'needs_review_this_cycle';
    }
    return 'stable_with_monitoring';
  }

  String _adviceFocus(AssetManagementInsightReport report) {
    if (report.emergencyAdvices.isNotEmpty) {
      return 'protect_living_expenses_before_payments';
    }
    if (report.movementSuggestions.isNotEmpty) {
      return 'move_cash_before_due_dates';
    }
    if (report.actionItems.any(
      (item) =>
          item.type == AssetManagementInsightActionType.missingAnnualRate ||
          item.type == AssetManagementInsightActionType.missingInput,
    )) {
      return 'fix_uncertain_debt_inputs';
    }
    if (report.actionItems.any(
      (item) =>
          item.type ==
              AssetManagementInsightActionType.cardBillingConfiguration ||
          item.type == AssetManagementInsightActionType.doubleCountingRisk,
    )) {
      return 'clean_card_billing_rules';
    }
    return 'keep_current_pace';
  }

  String _dueTimingBand(DateTime? dueDate, DateTime baseDate) {
    if (dueDate == null) return 'unknown';
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;
    if (days < 0) return 'overdue';
    if (days == 0) return 'today';
    if (days <= 3) return 'within_3_days';
    if (days <= 7) return 'within_7_days';
    if (due.year == today.year && due.month == today.month) {
      return 'later_this_month';
    }
    return 'future';
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

  String _amountPressureBand(double? amount) {
    if (amount == null) return 'not_applicable';
    final absolute = amount.abs();
    if (absolute == 0) return 'none';
    if (absolute < 10000) return 'low';
    if (absolute < 100000) return 'medium';
    return 'high';
  }

  dynamic _fingerprintValue(dynamic value) {
    if (value is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in value.entries) {
        normalized[entry.key.toString()] = _fingerprintValue(entry.value);
      }
      return normalized;
    }
    if (value is Iterable) {
      return value.map(_fingerprintValue).toList(growable: false);
    }
    if (value is String) {
      return _fingerprintString(value);
    }
    return value;
  }

  String _fingerprintString(String value) {
    if (!value.contains('T')) {
      return value;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    return _dateKey(parsed);
  }

  String _dateKey(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
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

  bool _containsJapaneseText(String value) {
    return RegExp('[\u3040-\u30ff\u3400-\u9fff]').hasMatch(value);
  }
}
