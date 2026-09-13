import '../domain/proactive_form_check_models.dart';

abstract class ProactiveFormValidator {
  Future<ProactiveValidationResult> validate(ProactiveFormDraft draft);
}

/// Runs deterministic checks asynchronously without sending form values away
/// from the device. The feature composition root can replace this implementation
/// when server-side policy checks are needed.
class RuleBasedProactiveFormValidator implements ProactiveFormValidator {
  const RuleBasedProactiveFormValidator({
    this.simulatedLatency = const Duration(milliseconds: 160),
  });

  final Duration simulatedLatency;

  @override
  Future<ProactiveValidationResult> validate(ProactiveFormDraft draft) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }

    return ProactiveValidationResult(<ProactiveValidationFinding>[
      ..._validateTitle(draft.title),
      ..._validateEmail(draft.email),
      ..._validateUrl(draft.destinationUrl),
      ..._validateBudget(draft.dailyBudget),
    ]);
  }

  Iterable<ProactiveValidationFinding> _validateTitle(String raw) sync* {
    final value = raw.trim();
    if (value.isEmpty) return;
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized != raw) {
      yield ProactiveValidationFinding(
        id: 'title-spacing',
        field: ProactiveFormField.title,
        severity: ValidationFindingSeverity.warning,
        message: 'タイトルに余分な空白が含まれています。',
        solution: '前後と連続する空白を整理すると、一覧で読みやすくなります。',
        suggestedValue: normalized,
      );
    }
    if (normalized.length < 6) {
      yield const ProactiveValidationFinding(
        id: 'title-too-short',
        field: ProactiveFormField.title,
        severity: ValidationFindingSeverity.warning,
        message: 'タイトルだけでは内容を判別しにくい可能性があります。',
        solution: '対象や目的が伝わる言葉を加えて、6文字以上にしてください。',
      );
    }
  }

  Iterable<ProactiveValidationFinding> _validateEmail(String raw) sync* {
    final value = raw.trim();
    if (value.isEmpty) return;
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(value)) {
      yield const ProactiveValidationFinding(
        id: 'email-format',
        field: ProactiveFormField.email,
        severity: ValidationFindingSeverity.blocking,
        message: '通知先メールアドレスの形式を確認できません。',
        solution: '「name@example.com」の形式で入力してください。',
      );
      return;
    }
    final atIndex = value.lastIndexOf('@');
    final normalized = '${value.substring(0, atIndex)}@'
        '${value.substring(atIndex + 1).toLowerCase()}';
    if (normalized != raw) {
      yield ProactiveValidationFinding(
        id: 'email-normalize',
        field: ProactiveFormField.email,
        severity: ValidationFindingSeverity.warning,
        message: 'メールアドレスのドメインに大文字または前後の空白があります。',
        solution: 'ローカル部を保ったままドメインを小文字にし、空白を取り除けます。',
        suggestedValue: normalized,
      );
    }
  }

  Iterable<ProactiveValidationFinding> _validateUrl(String raw) sync* {
    final value = raw.trim();
    if (value.isEmpty) return;
    final withScheme = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      yield const ProactiveValidationFinding(
        id: 'url-format',
        field: ProactiveFormField.destinationUrl,
        severity: ValidationFindingSeverity.blocking,
        message: '遷移先として利用できるURLを確認できません。',
        solution: '「https://example.com」のようにドメインまで入力してください。',
      );
      return;
    }
    if (!value.contains('://')) {
      yield ProactiveValidationFinding(
        id: 'url-scheme',
        field: ProactiveFormField.destinationUrl,
        severity: ValidationFindingSeverity.blocking,
        message: 'URLの通信方式が省略されています。',
        solution: '安全なHTTPSを先頭に追加してください。',
        suggestedValue: withScheme,
      );
    } else if (uri.scheme != 'https') {
      yield ProactiveValidationFinding(
        id: 'url-insecure',
        field: ProactiveFormField.destinationUrl,
        severity: ValidationFindingSeverity.blocking,
        message: '安全でないHTTPのURLが指定されています。',
        solution: '遷移先が対応していることを確認し、HTTPSへ変更してください。',
        suggestedValue: uri.replace(scheme: 'https').toString(),
      );
    }
  }

  Iterable<ProactiveValidationFinding> _validateBudget(String raw) sync* {
    final value = raw.trim();
    if (value.isEmpty) return;
    final normalized = value.replaceAll(RegExp(r'[,，円¥￥\s]'), '');
    final amount = int.tryParse(normalized);
    if (amount == null) {
      yield const ProactiveValidationFinding(
        id: 'budget-format',
        field: ProactiveFormField.dailyBudget,
        severity: ValidationFindingSeverity.blocking,
        message: '1日の予算を数値として読み取れません。',
        solution: '半角数字だけで入力してください（例: 3000）。',
      );
      return;
    }
    if (amount <= 0) {
      yield const ProactiveValidationFinding(
        id: 'budget-positive',
        field: ProactiveFormField.dailyBudget,
        severity: ValidationFindingSeverity.blocking,
        message: '1日の予算は1円以上にする必要があります。',
        solution: '運用可能な1日あたりの金額へ変更してください。',
        suggestedValue: '1000',
      );
    } else if (normalized != raw) {
      yield ProactiveValidationFinding(
        id: 'budget-normalize',
        field: ProactiveFormField.dailyBudget,
        severity: ValidationFindingSeverity.warning,
        message: '予算に数字以外の文字が含まれています。',
        solution: '保存時の誤解を防ぐため、半角数字へ統一できます。',
        suggestedValue: normalized,
      );
    }
  }
}
