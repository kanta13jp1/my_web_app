import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/ai_form_assistant.dart';
import 'package:my_web_app/pages/ai_form_assistant_page.dart';
import 'package:my_web_app/services/ai_form_assistant_service.dart';
import 'package:my_web_app/view_models/ai_form_assistant_view_model.dart';

void main() {
  testWidgets('AI proposal is shown for confirmation before fields change', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 900));
    final viewModel = await _buildViewModel(
      const AiFormAssistantReply(
        message: '設定案を作成しました。',
        changes: <AiFormChange>[
          AiFormChange(
            fieldId: 'workflow_name',
            value: '週次売上レポート',
            reason: '目的が分かる名前にしました',
          ),
          AiFormChange(
            fieldId: 'purpose',
            value: '売上の変化を週単位で確認する',
            reason: '依頼を具体化しました',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: AiFormAssistantPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-form-settings-panel')), findsOneWidget);
    expect(find.byKey(const Key('ai-form-chat-panel')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('ai-form-chat-input')),
      '毎週、売上レポートを作りたい',
    );
    await tester.tap(find.byKey(const Key('ai-form-send')));
    await tester.pumpAndSettle();

    expect(viewModel.valueFor('workflow_name'), '');
    expect(find.byKey(const Key('ai-form-proposal')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-form-review')));
    await tester.pumpAndSettle();
    expect(find.text('AIの変更案を適用しますか？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-form-apply')));
    await tester.pumpAndSettle();

    expect(viewModel.valueFor('workflow_name'), '週次売上レポート');
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('ai-form-field-workflow_name')),
          )
          .controller
          ?.text,
      '週次売上レポート',
    );
    expect(find.byKey(const Key('ai-form-proposal')), findsNothing);
  });

  testWidgets('manual field edit wins when an older proposal is confirmed', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 900));
    final viewModel = await _buildViewModel(
      const AiFormAssistantReply(
        message: '名前を提案しました。',
        changes: <AiFormChange>[
          AiFormChange(
            fieldId: 'workflow_name',
            value: 'AIの名前',
            reason: '依頼を要約',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AiFormAssistantPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-form-chat-input')),
      '名前を考えて',
    );
    await tester.tap(find.byKey(const Key('ai-form-send')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-form-field-workflow_name')),
      '手入力の最新名',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('ai-form-review')));
    await tester.pumpAndSettle();
    expect(find.text('手入力が更新されたため適用しません'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-form-apply')));
    await tester.pumpAndSettle();

    expect(viewModel.valueFor('workflow_name'), '手入力の最新名');
    expect(find.textContaining('1項目は保護しました'), findsOneWidget);
  });

  testWidgets('narrow layout stacks form and chat without overflow', (
    tester,
  ) async {
    await _setViewport(tester, const Size(480, 900));
    final viewModel = await _buildViewModel(
      const AiFormAssistantReply(message: 'お手伝いします。'),
    );
    await tester.pumpWidget(
      MaterialApp(home: AiFormAssistantPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-form-settings-panel')), findsOneWidget);
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-form-chat-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<AiFormAssistantViewModel> _buildViewModel(
  AiFormAssistantReply reply,
) async {
  final viewModel = AiFormAssistantViewModel(
    gateway: _FakeGateway(reply),
    settingsStore: _MemorySettingsStore(),
  );
  await viewModel.initialize();
  return viewModel;
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _FakeGateway implements AiFormAssistantGateway {
  const _FakeGateway(this.reply);

  final AiFormAssistantReply reply;

  @override
  Future<AiFormAssistantReply> propose({
    required String request,
    required Map<String, Object> currentValues,
    required List<AiFormChatMessage> history,
  }) async =>
      reply;
}

class _MemorySettingsStore implements AiFormSettingsStore {
  @override
  Future<Map<String, Object?>> load() async => <String, Object?>{};

  @override
  Future<void> save(Map<String, Object> values) async {}
}
