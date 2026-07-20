import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/satirical_print_library.dart';
import 'package:my_web_app/models/campaign_video.dart';

void main() {
  group('SatiricalPrintLibrary.all', () {
    test('is non-empty and covers all three campaign categories', () {
      final all = SatiricalPrintLibrary.all();
      expect(all.length, greaterThanOrEqualTo(6));
      final categories = all.map((v) => v.category).toSet();
      expect(categories, containsAll(CampaignCategory.values));
    });

    test('every entry id is unique and prefixed with print-', () {
      final all = SatiricalPrintLibrary.all();
      final ids = all.map((v) => v.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(all.every((v) => v.id.startsWith('print-')), isTrue);
    });
  });

  group('SatiricalPrintLibrary.dailyPicks', () {
    test('is deterministic for the same date', () {
      final a = SatiricalPrintLibrary.dailyPicks(DateTime(2026, 7, 19));
      final b = SatiricalPrintLibrary.dailyPicks(DateTime(2026, 7, 19));
      expect(a.map((v) => v.id).toList(), b.map((v) => v.id).toList());
    });

    test('returns the requested count of distinct prints', () {
      final picks = SatiricalPrintLibrary.dailyPicks(
        DateTime(2026, 7, 19),
        count: 3,
      );
      expect(picks.length, 3);
      expect(picks.map((v) => v.id).toSet().length, 3);
    });

    test('all picks come from the library', () {
      final ids = SatiricalPrintLibrary.all().map((v) => v.id).toSet();
      final picks = SatiricalPrintLibrary.dailyPicks(DateTime(2026, 1, 1));
      expect(picks.every((v) => ids.contains(v.id)), isTrue);
    });

    test('rotates across a week (not identical every day)', () {
      final sequences = <String>{};
      for (var day = 1; day <= 7; day++) {
        final picks = SatiricalPrintLibrary.dailyPicks(DateTime(2026, 7, day));
        sequences.add(picks.map((v) => v.id).join(','));
      }
      // 7 日間で少なくとも 2 通り以上の組み合わせが現れる (毎日入れ替わる)。
      expect(sequences.length, greaterThan(1));
    });

    test('handles count larger than library size gracefully', () {
      final picks = SatiricalPrintLibrary.dailyPicks(
        DateTime(2026, 7, 19),
        count: 999,
      );
      expect(picks.length, SatiricalPrintLibrary.all().length);
    });

    test('returns empty for non-positive count', () {
      expect(
        SatiricalPrintLibrary.dailyPicks(DateTime(2026, 7, 19), count: 0),
        isEmpty,
      );
    });
  });
}
