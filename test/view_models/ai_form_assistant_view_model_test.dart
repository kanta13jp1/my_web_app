import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/ai_form_assistant.dart';
import 'package:my_web_app/services/ai_form_assistant_service.dart';
import 'package:my_web_app/view_models/ai_form_assistant_view_model.dart';

void main() {
  test(
    'confirmed proposal preserves fields edited manually after generation',
    () async {
      final viewModel = AiFormAssistantViewModel(
        gateway: const _FakeGateway(
          AiFormAssistantReply(
            message: '2項目の案です',
            changes: <AiFormChange>[
              AiFormChange(
                fieldId: 'workflow_name',
                value: 'AIが提案した名前',
                reason: '目的を要約',
              ),
              AiFormChange(
                fieldId: 'purpose',
                value: 'AIが提案した目的',
                reason: '依頼内容を具体化',
              ),
            ],
          ),
        ),
        settingsStore: _MemorySettingsStore(),
      );
      await viewModel.initialize();

      await viewModel.submit('週次レポートを設定したい');
      expect(viewModel.valueFor('workflow_name'), '');
      expect(viewModel.pendingProposal, isNotNull);

      viewModel.updateField('workflow_name', '手入力した最新の名前');
      final result = viewModel.applyPendingProposal();

      expect(result.applied.map((change) => change.fieldId), <String>[
        'purpose',
      ]);
      expect(result.skipped.map((change) => change.fieldId), <String>[
        'workflow_name',
      ]);
      expect(viewModel.valueFor('workflow_name'), '手入力した最新の名前');
      expect(viewModel.valueFor('purpose'), 'AIが提案した目的');
      expect(viewModel.messages.last.text, contains('上書きせず保護'));
    },
  );

  test('manual edits made while AI is responding are also protected', () async {
    final completer = Completer<AiFormAssistantReply>();
    final gateway = _DeferredGateway(completer.future);
    final viewModel = AiFormAssistantViewModel(
      gateway: gateway,
      settingsStore: _MemorySettingsStore(),
    );
    await viewModel.initialize();

    final pending = viewModel.submit('通知先を設定したい');
    viewModel.updateField('notification_target', '#manual-latest');
    completer.complete(
      const AiFormAssistantReply(
        message: '通知先の案です',
        changes: <AiFormChange>[
          AiFormChange(
            fieldId: 'notification_target',
            value: '#ai-proposal',
            reason: '依頼から推定',
          ),
        ],
      ),
    );
    await pending;

    final result = viewModel.applyPendingProposal();
    expect(result.applied, isEmpty);
    expect(result.skipped, hasLength(1));
    expect(viewModel.valueFor('notification_target'), '#manual-latest');
  });

  test('valid settings are persisted and restored', () async {
    final store = _MemorySettingsStore();
    final first = AiFormAssistantViewModel(
      gateway: const _FakeGateway(AiFormAssistantReply(message: '変更はありません')),
      settingsStore: store,
    );
    await first.initialize();
    first
      ..updateField('workflow_name', '請求確認')
      ..updateField('purpose', '未処理の請求を毎週確認する')
      ..updateField('approver', '経理責任者');

    expect(await first.save(), isTrue);

    final restored = AiFormAssistantViewModel(
      gateway: const _FakeGateway(AiFormAssistantReply(message: '変更はありません')),
      settingsStore: store,
    );
    await restored.initialize();
    expect(restored.valueFor('workflow_name'), '請求確認');
    expect(restored.valueFor('approver'), '経理責任者');
  });
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

class _DeferredGateway implements AiFormAssistantGateway {
  const _DeferredGateway(this.future);

  final Future<AiFormAssistantReply> future;

  @override
  Future<AiFormAssistantReply> propose({
    required String request,
    required Map<String, Object> currentValues,
    required List<AiFormChatMessage> history,
  }) =>
      future;
}

class _MemorySettingsStore implements AiFormSettingsStore {
  Map<String, Object> values = <String, Object>{};

  @override
  Future<Map<String, Object?>> load() async =>
      Map<String, Object?>.from(values);

  @override
  Future<void> save(Map<String, Object> values) async {
    this.values = Map<String, Object>.from(values);
  }
}
