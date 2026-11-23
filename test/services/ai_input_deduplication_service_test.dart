import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_input_deduplication_service.dart';

void main() {
  group('AiInputDeduplicationService (#2697)', () {
    test('computes higher similarity for near-duplicates than distinct texts',
        () {
      final service = AiInputDeduplicationService();
      const baseText =
          'Competitor analysis report 2026: monthly active users grew 18 percent '
          'with AI workflow automation, enterprise SSO, and note collaboration.';
      const nearDuplicate =
          'Competitor analysis report 2026: monthly active users grew 19 percent '
          'with AI workflow automation, enterprise SSO, and note collaboration.';
      const unrelatedText =
          'Weather forecast for Tokyo tomorrow expects clear skies, mild winds '
          'from the bay, and afternoon temperatures around twenty-two degrees.';

      final sameDistance =
          service.computeNormalizedCompressionDistance(baseText, baseText);
      final nearSim =
          service.computeCompressionSimilarity(baseText, nearDuplicate);
      final diffSim =
          service.computeCompressionSimilarity(baseText, unrelatedText);

      expect(sameDistance, 0.0);
      expect(nearSim, greaterThan(diffSim));
      expect(nearSim, greaterThan(0.60));
    });

    test(
        'deduplicateInputs removes duplicates above threshold and logs savings',
        () {
      final service = AiInputDeduplicationService();
      final recorded = <AiDeduplicationLogEntry>[];

      const docA =
          'Executive briefing: recurring fixed cost optimization saved 42000 yen '
          'across cloud compute instances and storage tiers during Q4 review.';
      const docANear =
          'Executive briefing: recurring fixed cost optimization saved 42500 yen '
          'across cloud compute instances and storage tiers during Q4 review.';
      const docB =
          'Product launch checklist: verify mobile viewport semantics, confirm '
          'offline fallback banners, and publish release notes for testers.';

      final result = service.deduplicateInputs(
        const <String>[docA, docANear, docB, docA],
        similarityThreshold: 0.65,
        now: DateTime.utc(2026, 11, 24, 2, 0),
        onLog: recorded.add,
      );

      expect(result.keptInputs, <String>[docA, docB]);
      expect(result.removedIndices, <int>[1, 3]);
      expect(result.logEntry.totalInputs, 4);
      expect(result.logEntry.keptCount, 2);
      expect(result.logEntry.removedCount, 2);
      expect(result.logEntry.estimatedTokensSaved, greaterThan(0));
      expect(service.logs, hasLength(1));
      expect(recorded, hasLength(1));
    });

    test('handles empty input list cleanly with zero savings', () {
      final service = AiInputDeduplicationService();
      final result = service.deduplicateInputs(const <String>[]);

      expect(result.keptInputs, isEmpty);
      expect(result.removedIndices, isEmpty);
      expect(result.logEntry.removedCount, 0);
      expect(result.logEntry.estimatedTokensSaved, 0);
    });

    test('maintains symmetry, handles empty strings, and supports long text',
        () {
      final service = AiInputDeduplicationService();
      const first =
          'Quarterly engineering roadmap: Flutter Web CanvasKit selection '
          'and CI baseline stability improvements across workspace modules.';
      const second =
          'Architecture summary: Supabase Edge Function consolidation and '
          'Flutter Web selection optimization for mobile Safari users.';

      expect(
        service.computeNormalizedCompressionDistance(first, second),
        closeTo(
          service.computeNormalizedCompressionDistance(second, first),
          1e-9,
        ),
      );
      expect(service.computeNormalizedCompressionDistance('', ''), 0.0);
      expect(service.computeNormalizedCompressionDistance('', first), 1.0);

      final longBase = List<String>.filled(80, first).join(' ');
      final longNear = '$longBase extra note';
      final longUnrelated = List<String>.generate(
        80,
        (i) => 'Sensor $i telemetry metric ${(i * 17) % 97}',
      ).join(' ');
      final longNearSim = service.computeCompressionSimilarity(
        longBase,
        longNear,
      );
      final longDiffSim = service.computeCompressionSimilarity(
        longBase,
        longUnrelated,
      );
      expect(longNearSim, inInclusiveRange(0.55, 1.0));
      expect(longNearSim, greaterThan(longDiffSim));
    });

    test('falls back to raw byte size when compression throws', () {
      final service = AiInputDeduplicationService(
        compressor: (_) => throw StateError('compression unavailable'),
      );

      expect(service.compressedSize('abcd'), 4);
      final distance = service.computeNormalizedCompressionDistance(
        'alpha',
        'beta',
      );
      expect(distance, inInclusiveRange(0.0, 1.0));
    });
  });
}
