import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/dynamic_system_prompt_service.dart';

void main() {
  test('build places static prefix before dynamic UTC/JST context', () {
    final service = DynamicSystemPromptService(
      clock: () => DateTime.utc(2026, 11, 26, 12, 0, 0),
    );

    final first = service.build(
      outputFormat: DynamicSystemPromptOutputFormat.markdown,
      staticInstructions: 'Analyze {{domain}} telemetry.',
      templateVariables: const {'domain': 'budget'},
    );
    final second = service.build(
      now: DateTime.utc(2026, 11, 26, 16, 45, 0),
      outputFormat: DynamicSystemPromptOutputFormat.markdown,
      staticInstructions: 'Analyze {{domain}} telemetry.',
      templateVariables: const {'domain': 'budget'},
    );

    expect(first.staticPrefix, second.staticPrefix);
    expect(first.prompt.startsWith(first.staticPrefix), isTrue);
    expect(
      first.prompt.indexOf('Analyze budget telemetry.'),
      lessThan(first.prompt.indexOf('【動的コンテキスト】')),
    );
    expect(first.utcIso, '2026-11-26T12:00:00.000Z');
    expect(first.jstIso, '2026-11-26T21:00:00.000+09:00');
    expect(first.prompt, contains('fenced code blocks'));
  });

  test('build supports json_schema mode with schema name', () {
    final service = DynamicSystemPromptService(
      clock: () => DateTime.utc(2026, 11, 26, 0, 0, 0),
    );

    final built = service.build(
      outputFormat: DynamicSystemPromptOutputFormat.jsonSchema,
      jsonSchemaName: 'DecisionSummaryV1',
    );

    expect(built.staticPrefix, contains('requested schema only'));
    expect(built.staticPrefix, contains('Schema: DecisionSummaryV1'));
    expect(built.jstIso, '2026-11-26T09:00:00.000+09:00');
  });

  test('validateTemplate rejects missing, unclosed, and boundary tokens', () {
    final service = DynamicSystemPromptService();

    final valid = service.validateTemplate(
      'Run {{task}} checks.',
      variables: const {'task': 'audit'},
    );
    expect(valid.valid, isTrue);
    expect(valid.errors, isEmpty);

    final missing = service.validateTemplate(
      'Run {{task}} in {{env}}.',
      variables: const {'task': 'audit'},
    );
    expect(missing.valid, isFalse);
    expect(missing.unresolvedPlaceholders, ['env']);

    final unclosed = service.validateTemplate('Broken {{task');
    expect(unclosed.valid, isFalse);

    final boundary = service.validateTemplate('Inject <<<USER_DATA>>>');
    expect(boundary.valid, isFalse);

    expect(
      () => service.build(staticInstructions: 'Missing {{var}}'),
      throwsArgumentError,
    );
  });
}
