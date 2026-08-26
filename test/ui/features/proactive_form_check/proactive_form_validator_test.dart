import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/proactive_form_check/data/proactive_form_validator.dart';
import 'package:my_web_app/ui/features/proactive_form_check/domain/proactive_form_check_models.dart';

void main() {
  const validator = RuleBasedProactiveFormValidator(
    simulatedLatency: Duration.zero,
  );

  test('送信を妨げるメール・URL・予算の問題と具体的な解決策を返す', () async {
    final result = await validator.validate(
      const ProactiveFormDraft(
        title: '新商品キャンペーン',
        email: 'invalid-address',
        destinationUrl: 'example.com/campaign',
        dailyBudget: '-100',
      ),
    );

    expect(
      result.findings.map((finding) => finding.id),
      containsAll(<String>['email-format', 'url-scheme', 'budget-positive']),
    );
    expect(result.hasBlockingFinding, isTrue);
    expect(
      result.findings.every((finding) => finding.solution.isNotEmpty),
      isTrue,
    );
    expect(
      result.findings
          .singleWhere((finding) => finding.id == 'url-scheme')
          .suggestedValue,
      'https://example.com/campaign',
    );
  });

  test('安全な値はブロックせず、表記の統一案だけを返す', () async {
    final result = await validator.validate(
      const ProactiveFormDraft(
        title: ' 夏の   新商品キャンペーン ',
        email: 'USER@EXAMPLE.COM',
        destinationUrl: 'https://example.com/campaign',
        dailyBudget: '3,000円',
      ),
    );

    expect(result.hasBlockingFinding, isFalse);
    expect(
      result.findings.map((finding) => finding.suggestedValue),
      containsAll(<String>['夏の 新商品キャンペーン', 'USER@example.com', '3000']),
    );
  });

  test('メールのローカル部は変更せずドメインだけを正規化する', () async {
    final result = await validator.validate(
      const ProactiveFormDraft(email: ' CaseSensitive@EXAMPLE.COM '),
    );

    expect(
      result.findings
          .singleWhere((finding) => finding.id == 'email-normalize')
          .suggestedValue,
      'CaseSensitive@example.com',
    );
  });
}
