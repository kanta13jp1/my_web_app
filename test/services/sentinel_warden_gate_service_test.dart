import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/sentinel_warden_gate_service.dart';

void main() {
  test('evaluateOutput publishes clean output passing Sentinel and Warden', () {
    final service = SentinelWardenGateService();
    final res = service.evaluateOutput(
      id: 'out-1',
      sourceAction: 'ai.summary',
      content: '本日の家計サマリー: 食費と固定費のバランスは良好です。',
      structuredData: const {'summary': 'ok', 'category': 'finance'},
      requiredKeys: const ['summary', 'category'],
    );

    expect(res.disposition, GateDisposition.published);
    expect(res.publishable, isTrue);
    expect(res.sentinelPassed, isTrue);
    expect(res.wardenPassed, isTrue);
    expect(res.findings, isEmpty);
    expect(service.listRevisionQueue(), isEmpty);
  });

  test('evaluateOutput discards PII and queues schema failures', () {
    final service = SentinelWardenGateService();

    final pii = service.evaluateOutput(
      id: 'out-pii',
      sourceAction: 'ai.reply',
      content: '連絡先メールアドレスは private.user@example.com です。',
    );
    expect(pii.disposition, GateDisposition.discarded);
    expect(pii.publishable, isFalse);
    expect(pii.sentinelPassed, isFalse);

    final missingSchema = service.evaluateOutput(
      id: 'out-schema',
      sourceAction: 'ai.extract',
      content: '十分な長さのある構造化レポート本文です。',
      structuredData: const {'summary': 'ok'},
      requiredKeys: const ['summary', 'category'],
    );
    expect(missingSchema.disposition, GateDisposition.revisionQueue);
    expect(missingSchema.queuedItemId, 'rev-out-schema');
    expect(service.listRevisionQueue().length, 1);
  });

  test('evaluateOutput blocks Warden formatting issues and supports resolution',
      () {
    final service = SentinelWardenGateService();

    final badFormat = service.evaluateOutput(
      id: 'out-fmt',
      sourceAction: 'ai.code',
      content: '```dart\nfinal value = 42;\n未閉じのテンプレート {{user_name}}',
    );
    expect(badFormat.disposition, GateDisposition.revisionQueue);
    expect(badFormat.sentinelPassed, isTrue);
    expect(badFormat.wardenPassed, isFalse);
    expect(service.listRevisionQueue().length, 1);

    expect(service.resolveRevisionItem('rev-out-fmt'), isTrue);
    expect(service.listRevisionQueue(), isEmpty);
    expect(service.listRevisionQueue(includeResolved: true).length, 1);
  });
}
