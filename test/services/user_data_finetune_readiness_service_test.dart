import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/user_data_finetune_readiness_service.dart';

void main() {
  group('UserDataFineTuneReadinessSnapshot', () {
    test('parses Scale EGP-style readiness snapshot', () {
      final snapshot = UserDataFineTuneReadinessSnapshot.fromJson({
        'method': 'scale_egp_first_party_data_engine_v1',
        'total_records': 120,
        'eligible_records': 96,
        'blocked_records': 24,
        'quality_score': 82,
        'ready_for_eval_batch': true,
        'ready_for_fine_tune': false,
        'pii_risk': 'medium',
        'source_counts': {
          'ai_university_rlhf': 80,
          'daily_judgment_quality': 40,
        },
        'signal_summary': {
          'positive_signals': 60,
          'negative_signals': 10,
        },
        'kgi': 'Improve answer quality.',
        'csf': ['De-identify', 'Evaluate first'],
        'kpi': {
          'eligible_records_target': 100,
          'current_quality_score': 82,
        },
        'next_action': 'Create an evaluation batch first.',
      });

      expect(snapshot.method, 'scale_egp_first_party_data_engine_v1');
      expect(snapshot.eligibleRecords, 96);
      expect(snapshot.readyForEvalBatch, isTrue);
      expect(snapshot.readyForFineTune, isFalse);
      expect(snapshot.sourceCounts['daily_judgment_quality'], 40);
      expect(snapshot.signalSummary['positive_signals'], 60);
      expect(snapshot.eligibleTarget, 100);
      expect(snapshot.eligibleProgress, 0.96);
    });

    test('empty snapshot keeps tuning safely disabled', () {
      final snapshot = UserDataFineTuneReadinessSnapshot.empty();

      expect(snapshot.totalRecords, 0);
      expect(snapshot.readyForEvalBatch, isFalse);
      expect(snapshot.readyForFineTune, isFalse);
      expect(snapshot.eligibleProgress, 0);
      expect(snapshot.nextAction, contains('さらに集めましょう'));
    });
  });
}
