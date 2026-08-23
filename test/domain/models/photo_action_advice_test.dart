import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/photo_action_advice.dart';

void main() {
  test('parses, clamps, and orders safe action advice', () {
    final advice = PhotoActionAdvice.fromJson({
      'scene_summary': ' 冷蔵庫内に食品と調味料が見えます。 ',
      'observations': ['棚に汚れが見えます', '', 12, '容器が複数あります'],
      'actions': [
        {
          'priority': 3,
          'title': '容器をまとめる',
          'reason': '空間を把握しやすくするため',
          'estimated_minutes': 999,
        },
        {
          'priority': '1',
          'title': '食品表示を確認する',
          'reason': '写真だけでは期限を判断できないため',
          'estimated_minutes': 0,
          'caution': 'においや見た目だけで安全を断定しない',
        },
        {'priority': 2, 'title': '', 'reason': 'invalid'},
      ],
    });

    expect(advice.sceneSummary, '冷蔵庫内に食品と調味料が見えます。');
    expect(advice.observations, ['棚に汚れが見えます', '容器が複数あります']);
    expect(advice.actions, hasLength(2));
    expect(advice.actions.first.priority, PhotoActionPriority.urgent);
    expect(advice.actions.first.estimatedMinutes, 1);
    expect(advice.actions.last.estimatedMinutes, 180);
    expect(advice.confidenceNote, contains('写真に写っている範囲'));
  });

  test('rejects a response without any usable action', () {
    expect(
      () => PhotoActionAdvice.fromJson({
        'scene_summary': 'scene',
        'actions': [
          {'title': '', 'reason': ''},
        ],
      }),
      throwsFormatException,
    );
  });
}
