import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/tome_deck_studio_service.dart';

void main() {
  const service = TomeDeckStudioService();

  test('builds investor and internal report deck for Tome issue 756', () {
    final plan = service.buildPlan(
      scenario: TomeDeckScenario.investorDeck,
      topic: 'Life Management AI OS',
      audience: 'investors',
      sourceText: 'Current product connects AI analysis to KGI, CSF, KPI.',
    );

    expect(plan.issueNumber, 756);
    expect(plan.pageCount, 6);
    expect(plan.liveIntegrationReady, isTrue);
    expect(plan.kpi['pages'], 6);
    expect(plan.tomePrompt, contains('Life Management AI OS'));
    expect(plan.csf, hasLength(3));
  });

  test('builds AI University infographic plan for Tome issue 757', () {
    final plan = service.buildPlan(
      scenario: TomeDeckScenario.aiUniversityInfographic,
      topic: 'Tome provider lesson',
      audience: 'AI University learners',
      sourceText: 'Learners need compact visual lessons and quiz feedback.',
    );

    expect(plan.issueNumber, 757);
    expect(plan.pageCount, 5);
    expect(plan.kpi['visual_blocks'], 5);
    expect(
      plan.pages.map((page) => page.title),
      contains('インフォグラフィック書き出し'),
    );
    expect(plan.automationNotes.join('\n'), contains('クイズ失敗'));
  });

  test('parses Airtable-style rows for competitor deck issue 758', () {
    final plan = service.buildPlan(
      scenario: TomeDeckScenario.competitorAirtable,
      topic: 'Competitor weekly review',
      audience: 'product team',
      sourceText:
          'Product,Feature,Price,Risk\nTome,AI deck,Pro,workflow\nGamma,AI doc,Pro,speed\nAirtable,Data,Team,freshness',
    );

    final markdown = service.buildMarkdown(plan);

    expect(plan.issueNumber, 758);
    expect(plan.liveIntegrationReady, isFalse);
    expect(plan.kpi['airtable_rows_used'], 3);
    expect(plan.pages.first.narrative, contains('Tome, Gamma, Airtable'));
    expect(markdown, contains('自動化メモ'));
    expect(markdown, contains('Airtable'));
  });
}
