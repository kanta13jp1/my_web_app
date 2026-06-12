import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_management_ai_analysis_history.dart';
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
      expect(capturedBody?['max_tokens'], 3200);
      expect(capturedBody?['trace_id'], 'asset-management-ai-summary');
      expect(
        capturedBody?['message'].toString().contains('AIに渡す詳細ペイロード'),
        true,
      );
      expect(
        capturedBody?['message']
            .toString()
            .contains('GitHub Flavored Markdown'),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains('8. 最後にズバッと総評'),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains('細木数子'),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains('負債マスタ詳細'),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains('今月の支払いと利息'),
        true,
      );
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
            summaryText: '前回は支払い確認と生活費確保を最優先にした分析です。',
          ),
        ],
      );

      final message = capturedBody?['message'].toString() ?? '';
      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(message.contains('previous_ai_analyses'), true);
      expect(message.contains('これまでのAI分析履歴'), true);
      expect(message.contains('前回は支払い確認と生活費確保'), true);
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
        expect(calls.single['max_tokens'], 3200);
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

    test(
      'ai detailed payload includes exact account and debt values',
      () {
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
        expect(
          encoded.contains('external_ai_receives_exact_account_data'),
          true,
        );
        expect(
          encoded.contains('external_ai_receives_exact_profile_data'),
          true,
        );
        expect(
          encoded.contains('external_ai_receives_implementation_context'),
          true,
        );
      },
    );

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
      expect(
        guardrails['external_ai_receives_implementation_context'],
        true,
      );
      expect(
        guardrails['external_ai_may_reference_account_names'],
        true,
      );
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
      expect(message.contains('既知提案の再掲・言い換えは禁止'), true);
      expect(message.contains('ai-new-proposals'), true);
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
  });
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
    inputPayload: const <String, dynamic>{'sample': true},
  );
}
