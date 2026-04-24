import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/daily_judgment_quality_service.dart';

void main() {
  group('DailyJudgmentQualityEvaluation', () {
    test('parses Scale-style quality evaluation payload', () {
      final evaluation = DailyJudgmentQualityEvaluation.fromMap({
        'method': 'scale_evaluation_pattern_v1',
        'threshold': 80,
        'overall_score': 86,
        'passed': true,
        'quality_gate': 'approved',
        'monitoring_cadence': 'daily',
        'criteria': [
          {
            'id': 'actionability',
            'label': 'Actionability',
            'score': 90,
            'weight': 30,
            'reason': 'Executable today.',
          },
        ],
        'improvement_actions': ['Monitor outcome.'],
      });

      expect(evaluation.method, 'scale_evaluation_pattern_v1');
      expect(evaluation.overallScore, 86);
      expect(evaluation.needsReview, isFalse);
      expect(evaluation.criteria.single.id, 'actionability');
      expect(evaluation.improvementActions, ['Monitor outcome.']);
    });

    test('defaults to review state when evaluation is missing', () {
      final evaluation = DailyJudgmentQualityEvaluation.fromMap(null);

      expect(evaluation.overallScore, 0);
      expect(evaluation.threshold, 80);
      expect(evaluation.needsReview, isTrue);
      expect(evaluation.criteria, isEmpty);
    });

    test('clamps malformed numeric scores', () {
      final evaluation = DailyJudgmentQualityEvaluation.fromMap({
        'overall_score': '140',
        'threshold': '-1',
        'criteria': [
          {'id': 'clarity', 'score': -5, 'weight': 999},
        ],
      });

      expect(evaluation.overallScore, 100);
      expect(evaluation.threshold, 0);
      expect(evaluation.criteria.single.score, 0);
      expect(evaluation.criteria.single.weight, 100);
    });
  });
}
