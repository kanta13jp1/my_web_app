import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/palm_reading.dart';

void main() {
  test('parses a structured reading and clamps appearance scores', () {
    final reading = PalmReading.fromJson(_readingJson());

    expect(reading.id, 'reading-1');
    expect(reading.handSide, PalmHandSide.right);
    expect(reading.quality.score, 88);
    expect(reading.lines, hasLength(4));
    expect(reading.lines.first.label, '生命線');
    expect(reading.lines.first.visibility, 100);
    expect(reading.comparison.hasPrevious, isTrue);
    expect(
      reading.comparison.changes.single.direction,
      PalmChangeDirection.stronger,
    );
  });

  test('falls back safely when optional AI fields are absent', () {
    final reading = PalmReading.fromJson(<String, dynamic>{
      'id': 'minimal',
      'hand_side': 'unexpected',
      'analysis': <String, dynamic>{},
      'comparison': <String, dynamic>{},
    });

    expect(reading.handSide, PalmHandSide.left);
    expect(reading.lines, isEmpty);
    expect(reading.advice, isEmpty);
    expect(reading.comparison.confidence, 'low');
  });
}

Map<String, dynamic> _readingJson() => <String, dynamic>{
      'id': 'reading-1',
      'request_id': 'request-1',
      'hand_side': 'right',
      'image_path': 'user/reading-1.jpg',
      'image_mime_type': 'image/jpeg',
      'created_at': '2026-08-22T01:00:00Z',
      'provider': 'google',
      'model': 'gemini-2.5-flash',
      'schema_version': 1,
      'analysis': <String, dynamic>{
        'photo_quality': <String, dynamic>{
          'score': 88,
          'is_usable': true,
          'feedback': '鮮明です',
        },
        'overall': '自立心と柔軟さが見える手相です。',
        'traits': '考えてから動くタイプです。',
        'love': '信頼を大切にします。',
        'work': '企画力を生かせます。',
        'advice': <String>['小さく試す'],
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'life',
            'visibility': 120,
            'strength': 70,
            'continuity': 80,
            'shape': '大きな弧',
            'interpretation': '環境への柔軟さ',
          },
          for (final key in <String>['head', 'heart', 'fate'])
            <String, dynamic>{
              'key': key,
              'visibility': 60,
              'strength': 50,
              'continuity': 40,
              'shape': '穏やか',
              'interpretation': '参考の読み',
            },
        ],
      },
      'comparison': <String, dynamic>{
        'has_previous': true,
        'confidence': 'medium',
        'summary': '前回より生命線が明瞭に見えます。',
        'caution': '光の差を考慮してください。',
        'changes': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'life',
            'direction': 'stronger',
            'detail': '濃く見えます。',
          },
        ],
      },
    };
