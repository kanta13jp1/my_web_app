import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_rlhf_service.dart';

void main() {
  group('AiUniversityRlhfSnapshot', () {
    test('normalizes ratings and classifies preference labels', () {
      expect(AiUniversityRlhfSnapshot.normalizeRating(0), 1);
      expect(AiUniversityRlhfSnapshot.normalizeRating(3), 3);
      expect(AiUniversityRlhfSnapshot.normalizeRating(9), 5);

      expect(
        AiUniversityRlhfSnapshot.labelFor(rating: 5, helpful: true),
        'positive',
      );
      expect(
        AiUniversityRlhfSnapshot.labelFor(rating: 2, helpful: false),
        'negative',
      );
      expect(
        AiUniversityRlhfSnapshot.labelFor(rating: 3, helpful: true),
        'positive',
      );
    });

    test('builds Scale-style data quality score from learning signals', () {
      const signals = [
        AiUniversityRlhfSignal(
          providerId: 'scale_ai',
          rating: 5,
          helpful: true,
        ),
        AiUniversityRlhfSignal(
          providerId: 'scale_ai',
          rating: 4,
          helpful: true,
        ),
        AiUniversityRlhfSignal(
          providerId: 'argilla',
          rating: 3,
          helpful: true,
        ),
        AiUniversityRlhfSignal(
          providerId: 'openai',
          rating: 1,
          helpful: false,
        ),
      ];

      final snapshot = AiUniversityRlhfSnapshot.fromSignals(signals);

      expect(snapshot.totalSignals, 4);
      expect(snapshot.positiveSignals, 3);
      expect(snapshot.negativeSignals, 1);
      expect(snapshot.averageRating, 3.3);
      expect(snapshot.qualityScore, 75);
      expect(snapshot.providerSignalCounts['scale_ai'], 2);
      expect(snapshot.readyForFineTune, isFalse);
      expect(
        snapshot.nextAction,
        'Collect at least 20 preference signals before tuning.',
      );
    });

    test('marks dataset ready only after enough high quality signals', () {
      final signals = List.generate(
        20,
        (index) => AiUniversityRlhfSignal(
          providerId: index.isEven ? 'scale_ai' : 'argilla',
          rating: 5,
          helpful: true,
        ),
      );

      final snapshot = AiUniversityRlhfSnapshot.fromSignals(signals);

      expect(snapshot.readyForFineTune, isTrue);
      expect(snapshot.qualityScore, 100);
      expect(
        snapshot.nextAction,
        'Dataset is ready for fine-tuning or evaluation batches.',
      );
    });
  });
}
