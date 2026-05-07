import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/one_in_two_out_assist_service.dart';

void main() {
  test('lists two stale low-usage widgets for a new widget prompt', () {
    const service = OneInTwoOutAssistService();
    final now = DateTime.utc(2026, 5, 5, 12);

    final suggestion = service.buildSuggestion(
      incomingWidgetId: 'new-widget',
      incomingWidgetTitle: '新しい分析カード',
      now: now,
      existingWidgets: [
        WidgetUsageSignal(
          id: 'frequent',
          title: '毎日使う',
          sectionId: 'today',
          openCount: 30,
          lastUsedAt: now.subtract(const Duration(days: 1)),
        ),
        WidgetUsageSignal(
          id: 'stale-a',
          title: '古いカードA',
          sectionId: 'personal',
          openCount: 1,
          lastUsedAt: now.subtract(const Duration(days: 45)),
        ),
        const WidgetUsageSignal(
          id: 'never',
          title: '未使用カード',
          sectionId: 'personal',
          openCount: 0,
          lastUsedAt: null,
        ),
        WidgetUsageSignal(
          id: 'pinned',
          title: '固定カード',
          sectionId: 'personal',
          openCount: 0,
          lastUsedAt: now.subtract(const Duration(days: 120)),
          isPinned: true,
        ),
      ],
    );

    expect(suggestion.hasTwoCandidates, isTrue);
    expect(
      suggestion.candidates.map((candidate) => candidate.signal.id),
      <String>['never', 'stale-a'],
    );
    expect(suggestion.canSkip, isTrue);
    expect(suggestion.canOptOut, isTrue);
  });

  test('does not suggest incoming, hidden, or pinned widgets', () {
    const service = OneInTwoOutAssistService();

    final suggestion = service.buildSuggestion(
      incomingWidgetId: 'incoming',
      incomingWidgetTitle: '追加予定',
      now: DateTime.utc(2026, 5, 5),
      existingWidgets: const [
        WidgetUsageSignal(
          id: 'incoming',
          title: '追加予定',
          sectionId: 'personal',
          openCount: 0,
          lastUsedAt: null,
        ),
        WidgetUsageSignal(
          id: 'hidden',
          title: '非表示',
          sectionId: 'personal',
          openCount: 0,
          lastUsedAt: null,
          isVisible: false,
        ),
        WidgetUsageSignal(
          id: 'pinned',
          title: '固定',
          sectionId: 'personal',
          openCount: 0,
          lastUsedAt: null,
          isPinned: true,
        ),
        WidgetUsageSignal(
          id: 'candidate',
          title: '候補',
          sectionId: 'personal',
          openCount: 0,
          lastUsedAt: null,
        ),
      ],
    );

    expect(suggestion.candidates, hasLength(1));
    expect(suggestion.candidates.single.signal.id, 'candidate');
  });
}
