import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/prompt_templates/application/prompt_templates_controller.dart';
import 'package:my_web_app/features/prompt_templates/domain/prompt_template_models.dart';
import 'package:my_web_app/features/prompt_templates/prompt_templates_container.dart';

class _InMemoryPromptTemplateRepository implements PromptTemplateRepository {
  _InMemoryPromptTemplateRepository({
    final List<PromptTemplate>? initialTemplates,
  }) : _templates = List<PromptTemplate>.from(
          initialTemplates ?? <PromptTemplate>[],
        );

  final String? userId = 'usr-owner-1';
  final List<PromptTemplate> _templates;

  Completer<List<PromptTemplate>>? pendingLoad;
  Completer<PromptTemplate>? pendingSave;
  Completer<PromptTemplateSendResult>? pendingSend;

  bool throwOnLoad = false;
  bool throwOnSave = false;
  bool throwOnUsage = false;
  bool throwOnSend = false;

  int saveCalls = 0;
  int usageCalls = 0;
  int sendCalls = 0;
  String? lastSentPrompt;
  int _nextId = 1;

  @override
  String? get currentUserId => userId;

  @override
  Future<List<PromptTemplate>> listTemplates() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('load_error');
    }
    return List<PromptTemplate>.unmodifiable(_templates);
  }

  @override
  Future<PromptTemplate> saveTemplate(final PromptTemplateDraft draft) async {
    saveCalls++;
    if (pendingSave != null) {
      return pendingSave!.future;
    }
    if (throwOnSave) {
      throw StateError('save_error');
    }
    final now = DateTime.utc(2026, 11, 25, 5, 0);
    final editingId = draft.editingTemplateId;
    if (editingId != null && editingId.isNotEmpty) {
      final index = _templates.indexWhere(
        (final PromptTemplate item) => item.id == editingId,
      );
      if (index < 0) {
        throw StateError('template_not_found');
      }
      final updated = _templates[index].copyWith(
        title: draft.title.trim(),
        elements: draft.elements,
        isShared: draft.isShared,
        updatedAt: now,
      );
      _templates[index] = updated;
      return updated;
    }

    final created = PromptTemplate(
      id: 'tpl-${_nextId++}',
      userId: userId ?? 'usr-owner-1',
      title: draft.title.trim(),
      elements: draft.elements,
      isShared: draft.isShared,
      usageCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    _templates.insert(0, created);
    return created;
  }

  @override
  Future<void> deleteTemplate(final String templateId) async {
    _templates.removeWhere(
      (final PromptTemplate item) => item.id == templateId,
    );
  }

  @override
  Future<PromptTemplate> recordTemplateUsage(final String templateId) async {
    usageCalls++;
    if (throwOnUsage) {
      throw StateError('usage_error');
    }
    final index = _templates.indexWhere(
      (final PromptTemplate item) => item.id == templateId,
    );
    if (index < 0) {
      throw StateError('template_not_found');
    }
    final updated = _templates[index].copyWith(
      usageCount: _templates[index].usageCount + 1,
    );
    _templates[index] = updated;
    return updated;
  }

  @override
  Future<PromptTemplateSendResult> sendCompiledPrompt(
    final String compiledPrompt,
  ) async {
    sendCalls++;
    lastSentPrompt = compiledPrompt;
    if (pendingSend != null) {
      return pendingSend!.future;
    }
    if (throwOnSend) {
      throw StateError('upstream_api_unavailable');
    }
    return const PromptTemplateSendResult(
      responseText: '5要素プロンプトを受信し構成案を生成しました。',
      providerLabel: 'ai-hub/groq',
      latencyMs: 320,
    );
  }
}

List<PromptTemplate> _sampleTemplates() {
  final now = DateTime.utc(2026, 11, 25, 4, 30);
  return <PromptTemplate>[
    PromptTemplate(
      id: 'tpl-shared-1',
      userId: 'usr-teammate-2',
      title: '技術記事構成アナライザ',
      elements: const PromptElements(
        roleSetting: 'シニアアーキテクト兼エディター',
        contextInfo: '個人開発 SaaS の Supabase 最適化事例を解説する記事',
        deliverableDefinition: '導入・課題・設計・検証結果の4章構成案とタイトル案3つ',
        constraintsText: '推測値を含めず一次計測データのみを参照すること',
        thinkingProcess: '1) 課題分解 2) 技術根拠整理 3) 読者導線設計の順で考える',
      ),
      isShared: true,
      usageCount: 4,
      createdAt: now,
      updatedAt: now,
    ),
    PromptTemplate(
      id: 'tpl-mine-2',
      userId: 'usr-owner-1',
      title: '日次バックログ優先度整理',
      elements: const PromptElements(
        roleSetting: 'プロダクトマネージャー',
        contextInfo: '限られた1スプリント枠内で P0/P1 Issue を仕分ける場面',
        deliverableDefinition: '優先順位付きアクションリスト（工数見積・依存関係含む）',
        constraintsText: '既存の未完了受入条件を勝手に省略しないこと',
        thinkingProcess: 'リスク影響度 -> 依存ブロッカー -> 工数の順でスコアリングする',
      ),
      isShared: false,
      usageCount: 1,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

void main() {
  group('PromptElements & Domain Models (#2665)', () {
    test('validates all 5 elements independently and rejects excess lengths',
        () {
      const empty = PromptElements();
      final missingErrors = empty.validateErrors();
      expect(missingErrors, hasLength(5));
      expect(missingErrors[0], contains('役割設定'));
      expect(missingErrors[4], contains('思考プロセス'));

      final oversized = PromptElements(
        roleSetting: 'a' * (PromptTemplateLimits.maxRoleLength + 1),
        contextInfo: 'ok',
        deliverableDefinition: 'ok',
        constraintsText: 'ok',
        thinkingProcess: 'ok',
      );
      final lengthErrors = oversized.validateErrors();
      expect(lengthErrors, hasLength(1));
      expect(lengthErrors.first, contains('2000文字以内'));
    });

    test('compiles all 5 elements deterministically into plain text', () {
      const elements = PromptElements(
        roleSetting: 'AI エンジニア',
        contextInfo: 'Flutter Web 案件',
        deliverableDefinition: 'チェックリスト JSON',
        constraintsText: '型安全を維持する',
        thinkingProcess: '要件分解 -> 設計 -> 検証',
      );
      final compiled = elements.compilePlainText(title: '設計レビュー');
      expect(compiled, contains('# 設計レビュー'));
      expect(compiled, contains('## 1. 役割設定\nAI エンジニア'));
      expect(compiled, contains('## 2. コンテキスト情報\nFlutter Web 案件'));
      expect(compiled, contains('## 3. 成果物の定義\nチェックリスト JSON'));
      expect(compiled, contains('## 4. 制約条件\n型安全を維持する'));
      expect(compiled, contains('## 5. 思考プロセス\n要件分解 -> 設計 -> 検証'));
    });

    test(
        'parses Supabase row into PromptTemplate and generates insert/update payloads',
        () {
      final parsed = PromptTemplate.fromSupabaseRow(const <String, Object?>{
        'id': 'tpl-100',
        'user_id': 'usr-1',
        'title': '要約レビュー',
        'role_setting': 'エディター',
        'context_info': '開発ログ',
        'deliverable_definition': '3行要約',
        'constraints_text': '推測禁止',
        'thinking_process': '事実抽出 -> 要約',
        'is_shared': true,
        'usage_count': 7,
        'created_at': '2026-11-25T04:00:00Z',
        'updated_at': '2026-11-25T04:10:00Z',
      });

      expect(parsed.id, 'tpl-100');
      expect(parsed.isShared, isTrue);
      expect(parsed.usageCount, 7);
      expect(parsed.compiledPrompt, contains('## 3. 成果物の定義\n3行要約'));

      final draft = PromptTemplateDraft(
        title: parsed.title,
        elements: parsed.elements,
        isShared: true,
      );
      final payload = draft.toInsertPayload(userId: 'usr-1');
      expect(payload['user_id'], 'usr-1');
      expect(payload['role_setting'], 'エディター');
      expect(payload['thinking_process'], '事実抽出 -> 要約');
    });
  });

  group('PromptTemplatesController Unit Tests (#2665)', () {
    test('blocks concurrent saveDraft invocations using isSubmitting guard',
        () async {
      final completer = Completer<PromptTemplate>();
      final repo = _InMemoryPromptTemplateRepository()..pendingSave = completer;
      final controller = PromptTemplatesController(repository: repo)
        ..updateDraftTitle('二重送信防止テスト')
        ..updateRoleSetting('Role')
        ..updateContextInfo('Context')
        ..updateDeliverableDefinition('Deliverable')
        ..updateConstraintsText('Constraints')
        ..updateThinkingProcess('Thinking');

      final firstSave = controller.saveDraft();
      final secondSave = controller.saveDraft();

      expect(repo.saveCalls, 1);
      expect(controller.state.isSubmitting, isTrue);
      expect(await secondSave, isNull);

      final now = DateTime.utc(2026, 11, 25, 5, 0);
      completer.complete(
        PromptTemplate(
          id: 'tpl-completer-1',
          userId: 'usr-owner-1',
          title: '二重送信防止テスト',
          elements: controller.state.draftElements,
          isShared: false,
          usageCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final saved = await firstSave;
      expect(saved?.id, 'tpl-completer-1');
      expect(controller.state.isSubmitting, isFalse);
    });

    test('disposing during pending load does not throw or notify', () async {
      final completer = Completer<List<PromptTemplate>>();
      final repo = _InMemoryPromptTemplateRepository()..pendingLoad = completer;
      final controller = PromptTemplatesController(repository: repo);

      final loadFuture = controller.loadTemplates();
      controller.dispose();
      completer.complete(_sampleTemplates());
      await loadFuture;
    });

    test('reuseTemplate keeps prefill even if usage RPC fails fail-open',
        () async {
      final repo = _InMemoryPromptTemplateRepository(
        initialTemplates: _sampleTemplates(),
      )..throwOnUsage = true;
      final controller = PromptTemplatesController(repository: repo);
      await controller.loadTemplates();

      await controller.reuseTemplate(_sampleTemplates().first);
      expect(controller.state.draftElements.roleSetting, 'シニアアーキテクト兼エディター');
      expect(controller.state.draftTitle, contains('再利用'));
      expect(repo.usageCalls, 1);
      expect(controller.state.errorMessage, isNull);
    });
  });

  group('PromptTemplatesContainer Widget & Accessibility Tests (#2665)', () {
    Future<void> pumpPromptFeature(
      final WidgetTester tester, {
      required final _InMemoryPromptTemplateRepository repo,
      final Brightness brightness = Brightness.light,
      final Size? viewport,
      final double textScale = 1.0,
    }) async {
      final theme =
          brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (final BuildContext context) {
              final mediaQuery = MediaQuery.of(context).copyWith(
                size: viewport ?? MediaQuery.of(context).size,
                textScaler: TextScaler.linear(textScale),
              );
              return MediaQuery(
                data: mediaQuery,
                child: Scaffold(
                  body: PromptTemplatesContainer(
                    repository: repo,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'validates empty form and creates/searches/reuses/deletes templates', (
      final WidgetTester tester,
    ) async {
      final repo = _InMemoryPromptTemplateRepository(
        initialTemplates: _sampleTemplates(),
      );
      await pumpPromptFeature(tester, repo: repo);

      // Empty submit triggers validation without repository call.
      final saveButton = find.byKey(
        const ValueKey<String>('prompt-template-save-button'),
      );
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('prompt-template-error-banner')),
        findsOneWidget,
      );
      expect(repo.saveCalls, 0);

      // Enter all 5 elements independently and save shared template.
      for (final entry in const <MapEntry<String, String>>[
        MapEntry<String, String>('prompt-template-title-input', '新規5要素ナレッジ'),
        MapEntry<String, String>('prompt-template-role-input', 'セキュリティ監査官'),
        MapEntry<String, String>(
          'prompt-template-context-input',
          'Supabase Migration PR',
        ),
        MapEntry<String, String>(
          'prompt-template-deliverable-input',
          'Pass/Fail チェック表',
        ),
        MapEntry<String, String>(
          'prompt-template-constraints-input',
          'RLS 抜け漏れを許容しない',
        ),
        MapEntry<String, String>(
          'prompt-template-thinking-input',
          'テーブル権限 -> RLS -> トリガーの順に検証する',
        ),
      ]) {
        final field = find.byKey(ValueKey<String>(entry.key));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, entry.value);
      }
      final sharedSwitch = find.byKey(
        const ValueKey<String>('prompt-template-shared-switch'),
      );
      await tester.ensureVisible(sharedSwitch);
      await tester.pumpAndSettle();
      await tester.tap(sharedSwitch);
      await tester.pumpAndSettle();

      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.saveCalls, 1);
      expect(find.textContaining('新規5要素ナレッジ'), findsWidgets);

      // Filter by team shared and search by keyword.
      final filterSelect = find.byKey(
        const ValueKey<String>('prompt-template-filter-select'),
      );
      await tester.ensureVisible(filterSelect);
      await tester.pumpAndSettle();
      await tester.tap(filterSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('チーム共有').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('prompt-template-card-tpl-shared-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('prompt-template-card-tpl-mine-2')),
        findsNothing,
      );

      final searchInput = find.byKey(
        const ValueKey<String>('prompt-template-search-input'),
      );
      await tester.ensureVisible(searchInput);
      await tester.pumpAndSettle();
      await tester.enterText(searchInput, 'シニアアーキテクト');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('prompt-template-card-tpl-shared-1')),
        findsOneWidget,
      );

      // Reuse shared teammate template -> prefills all 5 fields + increments usage.
      final reuseButton = find.byKey(
        const ValueKey<String>('prompt-template-reuse-tpl-shared-1'),
      );
      await tester.ensureVisible(reuseButton);
      await tester.pumpAndSettle();
      await tester.tap(reuseButton);
      await tester.pumpAndSettle();

      expect(repo.usageCalls, 1);
      expect(find.text('シニアアーキテクト兼エディター'), findsWidgets);
      expect(find.textContaining('利用回数: 5'), findsOneWidget);

      // Clear search & filter back to all, then delete newly owned template.
      await tester.ensureVisible(searchInput);
      await tester.pumpAndSettle();
      await tester.enterText(searchInput, '');
      await tester.ensureVisible(filterSelect);
      await tester.pumpAndSettle();
      await tester.tap(filterSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('すべて').last);
      await tester.pumpAndSettle();

      final deleteOwnButton = find.byKey(
        const ValueKey<String>('prompt-template-delete-tpl-1'),
      );
      await tester.ensureVisible(deleteOwnButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteOwnButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('prompt-template-card-tpl-1')),
        findsNothing,
      );

      // Edit own existing template (tpl-mine-2) -> update & save.
      final editOwnButton = find.byKey(
        const ValueKey<String>('prompt-template-edit-tpl-mine-2'),
      );
      await tester.ensureVisible(editOwnButton);
      await tester.pumpAndSettle();
      await tester.tap(editOwnButton);
      await tester.pumpAndSettle();
      expect(find.text('テンプレートを更新'), findsOneWidget);

      final titleInput = find.byKey(
        const ValueKey<String>('prompt-template-title-input'),
      );
      await tester.ensureVisible(titleInput);
      await tester.pumpAndSettle();
      await tester.enterText(titleInput, '日次バックログ優先度整理 v2');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('日次バックログ優先度整理 v2'), findsWidgets);
    });

    testWidgets(
        'copies compiled prompt to Clipboard and handles external API send & fail-open errors',
        (
      final WidgetTester tester,
    ) async {
      final capturedPlatformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (final MethodCall methodCall) async {
          capturedPlatformCalls.add(methodCall);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final repo = _InMemoryPromptTemplateRepository(
        initialTemplates: _sampleTemplates(),
      );
      await pumpPromptFeature(tester, repo: repo);

      // Prefill from template so all 5 elements are valid.
      final reuseButton = find.byKey(
        const ValueKey<String>('prompt-template-reuse-tpl-shared-1'),
      );
      await tester.ensureVisible(reuseButton);
      await tester.tap(reuseButton);
      await tester.pumpAndSettle();

      // Copy compiled plain text via real Clipboard MethodChannel.
      final copyButton = find.byKey(
        const ValueKey<String>('prompt-template-copy-button'),
      );
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      final setDataCall = capturedPlatformCalls.lastWhere(
        (final MethodCall call) => call.method == 'Clipboard.setData',
      );
      final copiedMap = setDataCall.arguments as Map<Object?, Object?>;
      final copiedText = copiedMap['text']?.toString() ?? '';
      expect(copiedText, contains('## 1. 役割設定\nシニアアーキテクト兼エディター'));
      expect(copiedText, contains('## 5. 思考プロセス'));

      // Send compiled prompt to external API and verify response banner.
      final sendButton = find.byKey(
        const ValueKey<String>('prompt-template-send-button'),
      );
      await tester.ensureVisible(sendButton);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(repo.sendCalls, 1);
      expect(repo.lastSentPrompt, contains('## 3. 成果物の定義'));
      expect(
        find.byKey(
          const ValueKey<String>('prompt-template-api-response-card'),
        ),
        findsOneWidget,
      );

      // Fail-open error on next API send keeps user inputs intact.
      repo.throwOnSend = true;
      await tester.ensureVisible(sendButton);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('prompt-template-error-banner')),
        findsOneWidget,
      );
      expect(find.text('シニアアーキテクト兼エディター'), findsWidgets);
    });

    for (final viewport in const <Size>[Size(360, 800), Size(1280, 800)]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'meets WCAG/tap-target guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} ${brightness.name} 2.0x textScale',
          (final WidgetTester tester) async {
            final semanticsHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final repo = _InMemoryPromptTemplateRepository(
                initialTemplates: _sampleTemplates(),
              );
              await pumpPromptFeature(
                tester,
                repo: repo,
                brightness: brightness,
                viewport: viewport,
                textScale: 2.0,
              );

              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(textContrastGuideline),
              );
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
