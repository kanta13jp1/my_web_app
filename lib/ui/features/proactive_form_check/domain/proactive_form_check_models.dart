enum ProactiveFormField { title, email, destinationUrl, dailyBudget }

extension ProactiveFormFieldLabel on ProactiveFormField {
  String get label => switch (this) {
        ProactiveFormField.title => 'タイトル',
        ProactiveFormField.email => '通知先メールアドレス',
        ProactiveFormField.destinationUrl => '遷移先URL',
        ProactiveFormField.dailyBudget => '1日の予算',
      };
}

class ProactiveFormDraft {
  const ProactiveFormDraft({
    this.title = '',
    this.email = '',
    this.destinationUrl = '',
    this.dailyBudget = '',
  });

  final String title;
  final String email;
  final String destinationUrl;
  final String dailyBudget;

  bool get isEmpty =>
      title.isEmpty &&
      email.isEmpty &&
      destinationUrl.isEmpty &&
      dailyBudget.isEmpty;

  bool get hasAllRequiredValues =>
      title.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      destinationUrl.trim().isNotEmpty &&
      dailyBudget.trim().isNotEmpty;

  String valueFor(ProactiveFormField field) => switch (field) {
        ProactiveFormField.title => title,
        ProactiveFormField.email => email,
        ProactiveFormField.destinationUrl => destinationUrl,
        ProactiveFormField.dailyBudget => dailyBudget,
      };

  ProactiveFormDraft withValue(ProactiveFormField field, String value) {
    return ProactiveFormDraft(
      title: field == ProactiveFormField.title ? value : title,
      email: field == ProactiveFormField.email ? value : email,
      destinationUrl:
          field == ProactiveFormField.destinationUrl ? value : destinationUrl,
      dailyBudget:
          field == ProactiveFormField.dailyBudget ? value : dailyBudget,
    );
  }
}

enum ValidationFindingSeverity { warning, blocking }

class ProactiveValidationFinding {
  const ProactiveValidationFinding({
    required this.id,
    required this.field,
    required this.severity,
    required this.message,
    required this.solution,
    this.suggestedValue,
  });

  final String id;
  final ProactiveFormField field;
  final ValidationFindingSeverity severity;
  final String message;
  final String solution;
  final String? suggestedValue;

  bool get blocksSubmission => severity == ValidationFindingSeverity.blocking;
}

class ProactiveValidationResult {
  const ProactiveValidationResult(this.findings);

  final List<ProactiveValidationFinding> findings;

  bool get hasBlockingFinding =>
      findings.any((finding) => finding.blocksSubmission);
}
