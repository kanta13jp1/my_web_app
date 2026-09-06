import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/asset_management_ai_analysis_history.dart';
import 'package:my_web_app/models/daily_todo.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_provider_router.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

void main() {
  group('AssetManagementAiSummaryService', () {
    setUp(AiHubChatQuotaGuard.resetForTesting);

    test('does not call ai-hub when feature flag is off', () async {
      var calls = 0;
      final service = AssetManagementAiSummaryService(
        aiEnabled: false,
        chatService: AiHubChatService(
          invoker: (body) async {
            calls += 1;
            return <String, dynamic>{'success': true, 'text': 'should not run'};
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(calls, 0);
      expect(result.status, AssetManagementAiSummaryStatus.disabled);
      expect(result.usedExternalAi, false);
      expect(result.source.contains('feature flag off'), true);
      expect(result.text.contains('Dartルール'), true);
    });

    test('calls ai-hub auto chat when feature flag is on', () async {
      Map<String, dynamic>? capturedBody;
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            capturedBody = body;
            return <String, dynamic>{
              'success': true,
              'text': 'AIが生成した日本語要約です。',
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(result.usedExternalAi, true);
      expect(result.text, 'AIが生成した日本語要約です。');
      expect(capturedBody?['action'], 'provider.chat_auto');
      expect(capturedBody?['tier'], 'performance');
      // ai-hub 側で min(8192, ...) にクランプされるため実効値は 8192。
      expect(capturedBody?['max_tokens'], 8192);
      expect(capturedBody?['trace_id'], 'asset-management-ai-summary');
      expect(
        capturedBody?['message'].toString().contains('AIに渡す詳細ペイロード'),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains(
              'GitHub Flavored Markdown',
            ),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains('8. 最後にズバッと総評'),
        true,
      );
      expect(capturedBody?['message'].toString().contains('細木数子'), true);
      expect(capturedBody?['message'].toString().contains('負債マスタ詳細'), true);
      expect(capturedBody?['message'].toString().contains('今月の支払いと利息'), true);
      expect(
        capturedBody?['message'].toString().contains('英語の見出しや英語ラベルは使わないでください'),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains(
              '"external_ai_receives_exact_account_data":true',
            ),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains(
              '"must_respond_in_japanese":true',
            ),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains(
              '"external_ai_may_reference_exact_money_values":true',
            ),
        true,
      );
      expect(capturedBody?['message'].toString().contains('50,000'), true);
      expect(capturedBody?['message'].toString().contains('50000'), true);
      expect(capturedBody?['message'].toString().contains('PayPay'), true);
      expect(capturedBody?['message'].toString().contains('職業: 自営業'), true);
      expect(capturedBody?['message'].toString().contains('年収'), true);
      expect(capturedBody?['provider_choice_reason'], contains('summary'));
      expect(capturedBody?['routing_use_case'], 'summary');
    });

    test('includes previous persisted analyses in the AI prompt', () async {
      Map<String, dynamic>? capturedBody;
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            capturedBody = body;
            return <String, dynamic>{
              'success': true,
              'text': '過去分析を踏まえた日本語要約です。',
              'provider': 'openai',
            };
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(
        report: _report(),
        previousAnalyses: <AssetManagementAiAnalysisHistoryEntry>[
          _historyEntry(
            summaryText: '前回は支払い確認と生活費確保を最優先にした分析です。'
                '本日使用可能額は-27337円で安全残高未満、横浜銀行が期限超過で未払いよ。',
          ),
        ],
      );

      final message = capturedBody?['message'].toString() ?? '';
      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(message.contains('previous_ai_analyses'), true);
      expect(message.contains('これまでのAI分析履歴'), true);
      // 過去分析の本文(prose)は LLM へ渡さない (= 当時の期限超過/負の値を
      // 現在として再生産させないための物理除外)。
      expect(message.contains('前回は支払い確認と生活費確保'), false);
      expect(message.contains('横浜銀行が期限超過で未払い'), false);
      // 代わりにトレンド比較用の数値スナップショットだけを渡す。
      expect(message.contains('metrics_snapshot'), true);
      expect(message.contains('-7261960'), true);
      expect(message.contains('現在データ優先ルール'), true);
      expect(message.contains('履歴利用ルール'), true);
    });

    test(
      'routes through configured provider chain when routing is enabled',
      () async {
        final calls = <Map<String, dynamic>>[];
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          providerRouter: const AssetManagementAiProviderRouter(
            routingEnabled: true,
          ),
          chatService: AiHubChatService(
            invoker: (body) async {
              calls.add(Map<String, dynamic>.from(body));
              return <String, dynamic>{
                'success': true,
                'text': 'Claude経由の日本語要約です。',
                'observability': <String, dynamic>{
                  'provider': body['provider'],
                  'model': body['model'],
                },
              };
            },
          ),
          now: () => DateTime(2026, 5, 1, 12),
        );

        final result = await service.generateSummary(report: _report());

        expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
        expect(result.text, 'Claude経由の日本語要約です。');
        expect(calls, hasLength(1));
        expect(calls.single['action'], 'provider.chat');
        expect(calls.single['provider'], 'anthropic');
        expect(calls.single['model'], 'claude-opus-4-7');
        // ai-hub 側で min(8192, ...) にクランプされるため実効値は 8192。
        expect(calls.single['max_tokens'], 8192);
        expect(calls.single['routing_use_case'], 'summary');
        expect(
          calls.single['provider_choice_reason'],
          contains('claude-opus-4-7@anthropic'),
        );
        expect(result.providerRoute?['routing_enabled'], true);
      },
    );

    test(
      'provider routing falls back across providers before local summary',
      () async {
        final providers = <String>[];
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          providerRouter: const AssetManagementAiProviderRouter(
            routingEnabled: true,
          ),
          chatService: AiHubChatService(
            invoker: (body) async {
              providers.add(body['provider'] as String);
              if (body['provider'] == 'anthropic') {
                throw const AiHubChatException('temporary outage');
              }
              return <String, dynamic>{
                'success': true,
                'text': 'GPT経由の日本語要約です。',
                'provider': body['provider'],
              };
            },
          ),
          now: () => DateTime(2026, 5, 1, 12),
        );

        final result = await service.generateSummary(report: _report());

        expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
        expect(result.text, 'GPT経由の日本語要約です。');
        expect(providers, <String>['anthropic', 'openai']);
      },
    );

    test(
      'falls back when provider ignores the Japanese-only instruction',
      () async {
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          chatService: AiHubChatService(
            invoker: (body) async => <String, dynamic>{
              'success': true,
              'text': 'English-only summary',
              'provider': 'openai',
            },
          ),
          now: () => DateTime(2026, 5, 1, 12),
        );

        final result = await service.generateSummary(report: _report());

        expect(result.status, AssetManagementAiSummaryStatus.fallback);
        expect(result.usedExternalAi, false);
        expect(result.errorMessage, contains('日本語ではありません'));
        expect(result.text.contains('Dartルール'), true);
      },
    );

    test('rejects an AI summary that contradicts totals, rates, or paid state',
        () async {
      const planner = AssetLiabilityPlanningService();
      const insight = AssetManagementInsightService();
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 100000,
          'アコムカードローン': -500000,
        },
        baseDate: DateTime(2026, 9, 3),
        annualRateOverrides: const <String, double>{
          'acom_card_loan': 0.15,
        },
        paidAccountNames: const <String>{'acom_card_loan'},
      );
      final report = insight.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
        minimumSafetyBalance: 10000,
      );
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async => <String, dynamic>{
            'success': true,
            'text': '純資産は-700,000円。借入総額は800,000円。'
                'アコムカードローンの年利は18.0%で、今月分をすぐに払うべきです。',
            'provider': 'openai',
          },
        ),
        now: () => DateTime(2026, 9, 3, 12),
      );

      final result = await service.generateSummary(report: report);

      expect(result.status, AssetManagementAiSummaryStatus.fallback);
      expect(result.usedExternalAi, isFalse);
      expect(result.source, contains('grounding validation failed'));
      expect(result.errorMessage, contains('純資産が確定値と不一致'));
      expect(result.errorMessage, contains('アコムカードローンの年利が確定値と不一致'));
      expect(result.errorMessage, contains('支払済みなのに督促'));
    });

    test('accepts an AI summary grounded in current totals and confirmed rate',
        () async {
      const planner = AssetLiabilityPlanningService();
      const insight = AssetManagementInsightService();
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 100000,
          'アコムカードローン': -500000,
        },
        baseDate: DateTime(2026, 9, 3),
        annualRateOverrides: const <String, double>{
          'acom_card_loan': 0.15,
        },
        paidAccountNames: const <String>{'acom_card_loan'},
      );
      final report = insight.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
        minimumSafetyBalance: 10000,
      );
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async => <String, dynamic>{
            'success': true,
            'text': '純資産は-400,000円、負債合計は500,000円です。'
                'アコムカードローンの年利は15.00%で、今月分は支払済みです。',
            'provider': 'openai',
          },
        ),
        now: () => DateTime(2026, 9, 3, 12),
      );

      final result = await service.generateSummary(report: report);

      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(result.usedExternalAi, isTrue);
    });
    test('ai detailed payload includes exact account and debt values', () {
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 5, 1, 12),
      );

      final payload = service.buildAiDetailedPayload(_emergencyReport());
      final encoded = payload.toString();

      expect(encoded.contains('50000'), true);
      expect(encoded.contains('200000'), true);
      expect(encoded.contains('PayPay'), true);
      expect(encoded.contains('自営業'), true);
      expect(encoded.contains('annual_income'), true);
      expect(encoded.contains('favorite_foods'), true);
      expect(encoded.contains('debt_master_rows'), true);
      expect(encoded.contains('minimum_payment_estimate'), true);
      expect(encoded.contains('scheduled_payment_amount'), true);
      expect(encoded.contains('annual_rate'), true);
      expect(encoded.contains('monthly_interest_estimate'), true);
      expect(encoded.contains('liability_share'), true);
      expect(encoded.contains('available_money'), true);
      expect(encoded.contains('personal_context_signals'), true);
      expect(encoded.contains('priority_situation_cards'), true);
      expect(encoded.contains('recommended_next_step'), true);
      expect(encoded.contains('implementation_context'), true);
      expect(encoded.contains('source_references'), true);
      expect(encoded.contains('acceptance_criteria'), true);
      expect(encoded.contains('external_ai_receives_exact_account_data'), true);
      expect(encoded.contains('external_ai_receives_exact_profile_data'), true);
      expect(
        encoded.contains('external_ai_receives_implementation_context'),
        true,
      );
    });

    test('リボ払いカードはAIペイロードに内訳と注記を渡し差分を出さない', () {
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 6, 1, 12),
      );

      final payload = service.buildAiDetailedPayload(_revolvingReport());
      final encoded = payload.toString();

      expect(encoded.contains('is_revolving'), true);
      expect(encoded.contains('revolving_billing'), true);
      expect(encoded.contains('reconciliation_note'), true);
      expect(encoded.contains('statement_context'), true);
      expect(encoded.contains('new_usage_amount'), true);
      expect(encoded.contains('existing_balance_amount'), true);
      expect(encoded.contains('payment_day'), true);
      expect(encoded.contains('over_limit_amount'), false);
      expect(encoded.contains('ok_revolving_no_action_needed'), true);
      // カード請求グループ(au等の紐づけ負債)もリボ払いと明示し、請求額と比較させない。
      expect(encoded.contains('is_revolving_card'), true);
      // リボ払いでは比較対象になる生の合計・差分を top-level に置かない
      // (AI が請求額の隣で差を取り「不一致」と誤指摘するのを防ぐ)。
      expect(encoded.contains('configured_difference'), false);
      expect(encoded.contains('statement_difference'), false);
      expect(encoded.contains('configured_detail_total'), false);
      expect(encoded.contains('statement_line_total'), false);
    });

    test('falls back to deterministic text when ai-hub fails', () async {
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async => throw const AiHubChatException('boom'),
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.status, AssetManagementAiSummaryStatus.fallback);
      expect(result.usedExternalAi, false);
      expect(result.errorMessage?.contains('boom'), true);
      expect(result.text.contains('Dartルール'), true);
    });

    test(
      'routed summary passes a generous token budget for thinking models',
      () async {
        int? capturedMaxTokens;
        final chatService = AiHubChatService(
          invoker: (body) async {
            capturedMaxTokens = body['max_tokens'] as int?;
            return <String, dynamic>{
              'success': true,
              'text': 'これはAI要約のテスト本文です。',
              'provider': 'anthropic',
            };
          },
        );
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          chatService: chatService,
          providerRouter: const AssetManagementAiProviderRouter(
            routingEnabled: true,
          ),
          now: () => DateTime(2026, 6, 1, 12),
        );

        await service.generateSummary(report: _report());

        // ai-hub の `normalizeMaxTokens` が min(8192, ...) にクランプするため、
        // クライアントが 8192 超を送っても本番の実効値は 8192。ここでは
        // 「実効上限いっぱいを要求している」ことを検証する (旧テストは 16000 以上を
        // 期待していたが、その予算が本番で成立したことは一度も無かった)。
        // 実測の本文は ~3,000-3,500 トークンなので 8192 で十分な余裕がある。
        expect(capturedMaxTokens, isNotNull);
        expect(capturedMaxTokens, 8192);
      },
    );

    test('builds payload from calculated insights only', () {
      final report = _report();
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 5, 1, 12),
      );

      final payload = service.buildPayload(report);
      final available = payload['available_money'] as Map<String, dynamic>;
      final today = available['today'] as Map<String, dynamic>;
      final guardrails = payload['guardrails'] as Map<String, dynamic>;
      final emergencyAdvices = payload['emergency_advices'] as List<dynamic>;
      final workbook = payload['workbook'] as Map<String, dynamic>;
      final profile = payload['user_profile'] as Map<String, dynamic>;
      final debtRows = workbook['debt_master_rows'] as List<dynamic>;
      final developerRequests = payload['developer_requests'] as List<dynamic>;
      final implementationContext =
          payload['implementation_context'] as List<dynamic>;

      expect(payload.containsKey('workbook'), true);
      expect(debtRows, isNotEmpty);
      expect(profile['occupation'], '自営業');
      expect(profile['annual_income'], 452815 * 12);
      expect(today['available_amount'], report.todayAvailable.availableAmount);
      expect(payload['action_items'] is List<dynamic>, true);
      expect(payload['movement_suggestions'] is List<dynamic>, true);
      expect(emergencyAdvices.length, report.emergencyAdvices.length);
      expect(developerRequests, isNotEmpty);
      expect(
        developerRequests.first as Map<String, dynamic>,
        containsPair('acceptance_criteria', isA<List<String>>()),
      );
      expect(implementationContext, isNotEmpty);
      expect(guardrails['calculation_owner'], 'dart_service');
      expect(guardrails['external_ai_receives_exact_account_data'], true);
      expect(guardrails['external_ai_receives_exact_profile_data'], true);
      expect(guardrails['external_ai_receives_implementation_context'], true);
      expect(guardrails['external_ai_may_reference_account_names'], true);
      expect(guardrails['must_not_recommend_starvation_or_water_only'], true);
    });

    test('request fingerprint ignores volatile clock seconds', () {
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 5, 1, 12),
      );

      final morning = service.buildRequestFingerprint(
        _report(baseDate: DateTime(2026, 5, 1, 9, 0, 1)),
      );
      final evening = service.buildRequestFingerprint(
        _report(baseDate: DateTime(2026, 5, 1, 21, 59, 59)),
      );
      final nextDay = service.buildRequestFingerprint(
        _report(baseDate: DateTime(2026, 5, 2)),
      );

      expect(morning, evening);
      expect(morning, isNot(nextDay));
      expect(morning, startsWith('sha256:'));
      expect(morning, hasLength(71));
      expect(morning, isNot(contains('workbook')));
      expect(morning, isNot(contains('{')));
    });

    test(
      'waiting result keeps deterministic text before external AI returns',
      () {
        final service = AssetManagementAiSummaryService(
          now: () => DateTime(2026, 5, 1, 12),
        );

        final result = service.buildWaitingForAiResult(_report());

        expect(result.status, AssetManagementAiSummaryStatus.fallback);
        expect(result.usedExternalAi, false);
        expect(result.source, 'deterministic fallback / waiting for ai-hub');
        expect(result.text.contains('Dartルール'), true);
      },
    );

    test('deterministic fallback gives concrete emergency living advice', () {
      final report = _emergencyReport();
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 5, 28, 12),
      );

      final text = service.buildDeterministicSummary(report);
      final payload = service.buildPayload(report);

      expect(text.contains('今日の食費'), true);
      expect(text.contains('支払い'), true);
      expect(text.contains('Dartルール'), true);
      expect(payload['emergency_advices'] is List<dynamic>, true);
      expect((payload['emergency_advices'] as List<dynamic>).isNotEmpty, true);
    });

    test('annotates issued requests and demands novel proposals', () async {
      final report = _reportWithDeveloperRequests();
      expect(report.developerRequests, isNotEmpty);
      final issuedTitle = report.developerRequests.first.title;

      Map<String, dynamic>? capturedBody;
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            capturedBody = body;
            return <String, dynamic>{
              'success': true,
              'text': 'AIが生成した日本語要約です。',
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 6, 12, 12),
      );

      await service.generateSummary(
        report: report,
        existingDeveloperIssuesByTitle: <String, Map<String, dynamic>>{
          issuedTitle: <String, dynamic>{
            'number': 3064,
            'state': 'closed',
            'title': issuedTitle,
            'html_url': 'https://github.com/example/repo/issues/3064',
          },
        },
      );

      final message = capturedBody?['message'].toString() ?? '';
      expect(message.contains('"already_issued":true'), true);
      expect(message.contains('"number":3064'), true);
      expect(message.contains('既にGitHub Issue起票済み'), true);
      expect(message.contains('本文にもJSONにも出力禁止'), true);
      expect(message.contains('新規提案なし（既知の提案はすべて起票済みです）'), true);
      expect(message.contains('起票済み。本文・JSONブロックとも再掲禁止。'), true);
      expect(message.contains('ai-new-proposals'), true);
      // 起票済みテンプレートの本文 (echo の材料) はプロンプトへ渡さない。
      expect(
        message.contains(report.developerRequests.first.description),
        false,
      );
      expect(message.contains('本文・JSONとも再掲禁止'), true);
    });

    test('extracts ai proposal block into issueable requests', () async {
      final response = [
        '## 7. 開発者向け改善提案',
        '- 新規提案: 負債マスタの一括編集モード',
        '',
        '```json ai-new-proposals',
        '[{"title":"負債マスタの一括編集モード",'
            '"description":"請求確定待ちの負債をまとめて編集できるようにする。",'
            '"evidence":["推定額の負債行: 2件"],'
            '"implementation_steps":["一括編集UIを追加"],'
            '"acceptance_criteria":["複数行を同時に保存できる"],'
            '"source_references":["lib/pages/asset_management_page.dart"]}]',
        '```',
        '',
        '## 8. 最後にズバッと総評',
        '以上。',
      ].join('\n');
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            return <String, dynamic>{
              'success': true,
              'text': response,
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 6, 12, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.aiDeveloperRequests, hasLength(1));
      final request = result.aiDeveloperRequests.single;
      expect(request.title, '負債マスタの一括編集モード');
      expect(request.acceptanceCriteria, contains('複数行を同時に保存できる'));
      expect(
        request.sourceReferences,
        contains('lib/pages/asset_management_page.dart'),
      );
      expect(result.text.contains('ai-new-proposals'), false);
      expect(result.text.contains('一括編集UIを追加'), false);
      expect(result.text.contains('## 8. 最後にズバッと総評'), true);
    });

    test('drops broken ai proposal block safely', () async {
      final response = [
        '## 7. 開発者向け改善提案',
        '提案本文です。',
        '```json ai-new-proposals',
        'これはJSONではありません',
        '```',
        '## 8. 最後にズバッと総評',
        '以上。',
      ].join('\n');
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            return <String, dynamic>{
              'success': true,
              'text': response,
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 6, 12, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.aiDeveloperRequests, isEmpty);
      expect(result.text.contains('ai-new-proposals'), false);
      expect(result.text.contains('## 8. 最後にズバッと総評'), true);
    });

    test('parses marker on the line after the fence', () async {
      final response = [
        '## 7. 開発者向け改善提案',
        '- 新規提案: サンプル',
        '',
        '```json',
        'ai-new-proposals',
        '[{"title":"サンプル新規提案","description":"説明です。"}]',
        '```',
        '',
        '## 8. 最後にズバッと総評',
        '以上。',
      ].join('\n');
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            return <String, dynamic>{
              'success': true,
              'text': response,
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 6, 12, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.aiDeveloperRequests, hasLength(1));
      expect(result.aiDeveloperRequests.single.title, 'サンプル新規提案');
      expect(result.text.contains('ai-new-proposals'), false);
      expect(result.text.contains('```json'), false);
      expect(result.text.contains('## 8. 最後にズバッと総評'), true);
    });

    test('filters proposals that repeat known template titles', () async {
      final report = _reportWithDeveloperRequests();
      expect(report.developerRequests, isNotEmpty);
      final knownTitle = report.developerRequests.first.title;
      final response = [
        '## 7. 開発者向け改善提案',
        '提案本文です。',
        '```json ai-new-proposals',
        '[{"title":"$knownTitle","description":"既知提案の再掲です。"},'
            '{"title":"全く新しい改善提案","description":"新規の提案です。"}]',
        '```',
        '## 8. 最後にズバッと総評',
        '以上。',
      ].join('\n');
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            return <String, dynamic>{
              'success': true,
              'text': response,
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 6, 12, 12),
      );

      final result = await service.generateSummary(report: report);

      expect(result.aiDeveloperRequests, hasLength(1));
      expect(result.aiDeveloperRequests.single.title, '全く新しい改善提案');
    });

    test('ignores prose mention of the marker without a block', () async {
      final response = [
        '## 7. 開発者向け改善提案',
        '今回は ai-new-proposals に該当する新規提案はありません。',
        '## 8. 最後にズバッと総評',
        '以上。',
      ].join('\n');
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            return <String, dynamic>{
              'success': true,
              'text': response,
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 6, 12, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.aiDeveloperRequests, isEmpty);
      expect(result.text, response);
    });
  });

  group('daily_todo をAIペイロードへ載せる', () {
    final service = AssetManagementAiSummaryService(aiEnabled: false);

    test('digest があり非空なら daily_todo を含み、行動の借金/実績を渡す', () {
      final now = DateTime(2026, 7, 31, 22);
      final digest = DailyTodoDigest.fromState(
        tasks: <DailyTodoTask>[
          DailyTodoTask(id: 'today', title: '今日の分', plannedDate: now),
          DailyTodoTask(
            id: 'debt',
            title: '溜めた借金',
            plannedDate: DateTime(2026, 7, 28),
          ),
        ],
        log: const <DailyTodoCompletionLogEntry>[],
        now: now,
      );
      final payload = service.buildAiDetailedPayload(
        _reportWithDailyTodo(digest: digest),
      );
      expect(payload.containsKey('daily_todo'), isTrue);
      final todo = payload['daily_todo'] as Map<String, dynamic>;
      expect(todo['today_total'], 1);
      expect(todo['carried_over_count'], 1);
      expect(todo['max_carry_over_days'], 3);
    });

    test('digest が null なら daily_todo を含まない', () {
      final payload = service.buildAiDetailedPayload(_report());
      expect(payload.containsKey('daily_todo'), isFalse);
    });

    test('digest が空(ToDo未使用)なら daily_todo を含まない', () {
      final emptyDigest = DailyTodoDigest.fromState(
        tasks: const <DailyTodoTask>[],
        log: const <DailyTodoCompletionLogEntry>[],
        now: DateTime(2026, 7, 31),
      );
      expect(emptyDigest.isEmpty, isTrue);
      final payload = service.buildAiDetailedPayload(
        _reportWithDailyTodo(digest: emptyDigest),
      );
      expect(payload.containsKey('daily_todo'), isFalse);
    });
  });
}

AssetManagementInsightReport _reportWithDailyTodo({DailyTodoDigest? digest}) {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
    baseDate: DateTime(2026, 7, 31),
  );
  return insight.buildReport(
    workbook: workbook,
    userProfile: _userProfile(),
    minimumSafetyBalance: 10000,
    dailyTodoDigest: digest,
  );
}

AssetManagementInsightReport _reportWithDeveloperRequests() {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
    baseDate: DateTime(2026, 6, 1),
  );
  return insight.buildReport(
    workbook: workbook,
    userProfile: _userProfile(),
    minimumSafetyBalance: 10000,
  );
}

AssetManagementInsightReport _report({DateTime? baseDate}) {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
    baseDate: baseDate ?? DateTime(2026, 5, 1),
    monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
    paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
  );
  return insight.buildReport(
    workbook: workbook,
    userProfile: _userProfile(),
    minimumSafetyBalance: 10000,
  );
}

AssetManagementInsightReport _emergencyReport() {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -200000},
    baseDate: DateTime(2026, 5, 28),
    monthlyPaymentOverrides: const <String, double>{'paypay_card': 200000},
    paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
  );
  return insight.buildReport(
    workbook: workbook,
    userProfile: _userProfile(),
    minimumSafetyBalance: 10000,
  );
}

AssetManagementInsightReport _revolvingReport() {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: const <String, double>{
      'cash': 50000,
      'auPayカード': -530163,
      'au': -32152,
    },
    baseDate: DateTime(2026, 6, 1),
    revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
      'aupay_card': AssetLiabilityRevolvingCreditConfig(
        monthlyAmount: 10000,
        creditLimit: 500000,
      ),
    },
    cardBillingAccountIds: const <String, String>{'au': 'aupay_card'},
    cardStatementLines: const <AssetLiabilityCardStatementLine>[
      AssetLiabilityCardStatementLine(
        id: 'l1',
        billingAccountId: 'aupay_card',
        billingAccountName: 'auPayカード',
        postedAt: null,
        description: 'レモンガス',
        amount: 8066,
      ),
    ],
  );
  return insight.buildReport(
    workbook: workbook,
    userProfile: _userProfile(),
    minimumSafetyBalance: 10000,
  );
}

UserProfile _userProfile() {
  return UserProfile(
    userId: 'user-1',
    displayName: 'kanta',
    bio: '借金を減らして生活を立て直したい',
    location: '東京都',
    birthDate: DateTime(1978, 9, 30),
    targetDeathAge: 85,
    gender: '男',
    occupation: '自営業',
    annualIncome: 452815 * 12,
    address: '東京都豊島区',
    education: '大学卒',
    careerHistory: '営業、Web開発、個人事業',
    hobbies: 'AIツール検証、音楽',
    alcoholUse: '時々',
    smokingUse: '吸わない',
    favoriteFoods: 'カレー、焼肉',
  );
}

AssetManagementAiAnalysisHistoryEntry _historyEntry({
  required String summaryText,
}) {
  return AssetManagementAiAnalysisHistoryEntry(
    id: 'history-1',
    requestFingerprint: 'fingerprint-1',
    summaryText: summaryText,
    status: AssetManagementAiSummaryStatus.aiGenerated.name,
    source: 'ai-hub provider.chat_auto / openai',
    generatedAt: DateTime(2026, 4, 30, 12),
    createdAt: DateTime(2026, 4, 30, 12),
    reportBaseDate: DateTime(2026, 4, 30),
    providerChoiceReason: 'test route',
    providerRoute: const <String, dynamic>{'provider': 'openai'},
    inputPayload: const <String, dynamic>{
      'workbook': <String, dynamic>{
        'totals': <String, dynamic>{
          'net_worth': -7261960,
          'liability_total': -7412535,
          'monthly_unpaid_payment_total': 356052,
          'monthly_actual_payment_total': 0,
        },
      },
      'available_money': <String, dynamic>{
        'today': <String, dynamic>{'available_amount': -27337},
        'week': <String, dynamic>{'available_amount': -20000},
        'month': <String, dynamic>{'available_amount': -10000},
      },
    },
  );
}
