import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/proactive_form_check/data/proactive_form_validator.dart';
import 'package:my_web_app/ui/features/proactive_form_check/domain/proactive_form_check_models.dart';
import 'package:my_web_app/ui/features/proactive_form_check/view_models/proactive_form_check_view_model.dart';

void main() {
  group('ProactiveFormCheckViewModel', () {
    test('有効な入力の検証後だけ送信を許可する', () async {
      final viewModel = ProactiveFormCheckViewModel(
        validator: const RuleBasedProactiveFormValidator(
          simulatedLatency: Duration.zero,
        ),
        debounceDuration: Duration.zero,
      );
      addTearDown(viewModel.dispose);

      viewModel
        ..updateField(ProactiveFormField.title, '夏の新商品キャンペーン')
        ..updateField(ProactiveFormField.email, 'owner@example.com')
        ..updateField(
          ProactiveFormField.destinationUrl,
          'https://example.com/campaign',
        )
        ..updateField(ProactiveFormField.dailyBudget, '3000');
      await viewModel.validateNow();

      expect(viewModel.status, ProactiveValidationStatus.ready);
      expect(viewModel.visibleFindings, isEmpty);
      expect(viewModel.canSubmit, isTrue);
    });

    test('修正案を値へ反映してすぐに再検証する', () async {
      final viewModel = ProactiveFormCheckViewModel(
        validator: const RuleBasedProactiveFormValidator(
          simulatedLatency: Duration.zero,
        ),
      );
      addTearDown(viewModel.dispose);
      viewModel.updateField(
        ProactiveFormField.destinationUrl,
        'example.com/campaign',
      );
      await viewModel.validateNow();
      final finding = viewModel.visibleFindings.singleWhere(
        (candidate) => candidate.id == 'url-scheme',
      );

      await viewModel.applySuggestion(finding);

      expect(viewModel.draft.destinationUrl, 'https://example.com/campaign');
      expect(
        viewModel.visibleFindings.where(
          (candidate) => candidate.id == 'url-scheme',
        ),
        isEmpty,
      );
    });

    test('遅れて返った古い検証結果を画面へ反映しない', () async {
      final validator = _ControlledValidator();
      final viewModel = ProactiveFormCheckViewModel(
        validator: validator,
        debounceDuration: const Duration(days: 1),
      );
      addTearDown(viewModel.dispose);

      viewModel.updateField(ProactiveFormField.email, 'old@example.com');
      final firstRun = viewModel.validateNow();
      viewModel.updateField(ProactiveFormField.email, 'new@example.com');
      final secondRun = viewModel.validateNow();

      validator.requests[1].complete(
        const ProactiveValidationResult(<ProactiveValidationFinding>[]),
      );
      await secondRun;
      validator.requests[0].complete(
        const ProactiveValidationResult(<ProactiveValidationFinding>[
          ProactiveValidationFinding(
            id: 'stale-error',
            field: ProactiveFormField.email,
            severity: ValidationFindingSeverity.blocking,
            message: '古いエラー',
            solution: '古い解決策',
          ),
        ]),
      );
      await firstRun;

      expect(viewModel.draft.email, 'new@example.com');
      expect(viewModel.visibleFindings, isEmpty);
      expect(viewModel.status, ProactiveValidationStatus.ready);
    });

    test('再検証中の二重送信を1回に制限する', () async {
      final viewModel = ProactiveFormCheckViewModel(
        validator: const RuleBasedProactiveFormValidator(
          simulatedLatency: Duration(milliseconds: 20),
        ),
        debounceDuration: Duration.zero,
      );
      addTearDown(viewModel.dispose);
      viewModel
        ..updateField(ProactiveFormField.title, '夏の新商品キャンペーン')
        ..updateField(ProactiveFormField.email, 'owner@example.com')
        ..updateField(
          ProactiveFormField.destinationUrl,
          'https://example.com/campaign',
        )
        ..updateField(ProactiveFormField.dailyBudget, '3000');
      await viewModel.validateNow();

      final first = viewModel.submit();
      final second = viewModel.submit();

      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.wasSubmitted, isTrue);
    });
  });
}

class _ControlledValidator implements ProactiveFormValidator {
  final List<Completer<ProactiveValidationResult>> requests =
      <Completer<ProactiveValidationResult>>[];

  @override
  Future<ProactiveValidationResult> validate(ProactiveFormDraft draft) {
    final request = Completer<ProactiveValidationResult>();
    requests.add(request);
    return request.future;
  }
}
