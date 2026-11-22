import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/savored_moment.dart';

void main() {
  final now = DateTime(2026, 11, 17, 21);

  SavoredMoment moment(int id, DateTime day, {String? note, int minute = 0}) {
    return SavoredMoment(
      id: id,
      note: note ?? 'moment $id',
      momentDate: day,
      createdAt: DateTime(day.year, day.month, day.day, 12, minute),
    );
  }

  group('normalizeSavoredMomentNote', () {
    test('trims and rejects blank or over-long lines', () {
      expect(normalizeSavoredMomentNote('  夕焼けがきれいだった \n'), '夕焼けがきれいだった');
      expect(normalizeSavoredMomentNote(''), isNull);
      expect(normalizeSavoredMomentNote('   \n\t'), isNull);
      expect(normalizeSavoredMomentNote('あ' * 200), hasLength(200));
      expect(normalizeSavoredMomentNote('あ' * 201), isNull);
      // Surrounding whitespace does not count toward the limit, as in the DB.
      expect(normalizeSavoredMomentNote('  ${'あ' * 200}  '), hasLength(200));
    });
  });

  group('SavoredMomentDigest', () {
    test('splits today from recent and orders each for reading', () {
      final digest = SavoredMomentDigest.fromMoments(
        moments: [
          moment(5, DateTime(2026, 11, 17), minute: 30),
          moment(4, DateTime(2026, 11, 17), minute: 10),
          moment(3, DateTime(2026, 11, 15)),
          moment(2, DateTime(2026, 11, 16)),
          moment(1, DateTime(2026, 11, 16)),
        ],
        now: now,
      );

      expect(digest.today.map((m) => m.id), [4, 5]);
      expect(digest.recent.map((m) => m.id), [2, 1, 3]);
    });

    test('recall keeps only a few, inside the window, without duplicates', () {
      final firstDay = SavoredMomentDigest.windowStart(now);
      expect(firstDay, DateTime(2026, 11, 4));

      final digest = SavoredMomentDigest.fromMoments(
        moments: [
          moment(10, DateTime(2026, 11, 3)), // one day before the window
          moment(11, firstDay),
          moment(12, DateTime(2026, 11, 10)),
          moment(12, DateTime(2026, 11, 10)),
          moment(13, DateTime(2026, 11, 12)),
          moment(14, DateTime(2026, 11, 14)),
          moment(15, DateTime(2026, 11, 18)), // tomorrow
        ],
        now: now,
      );

      expect(digest.today, isEmpty);
      expect(digest.recent, hasLength(SavoredMomentDigest.recentLimit));
      expect(digest.recent.map((m) => m.id), [14, 13, 12]);
    });

    test('the model exposes no score, rating or count to show', () {
      // The point of the feature is to record without grading. Guard against
      // a later change quietly adding a metric to the digest or the table.
      final sql = File(
        'supabase/migrations/20261117090000_create_prison_savored_moments.sql',
      ).readAsStringSync().toLowerCase();
      final columns = RegExp(
        r'create table if not exists public\.prison_savored_moments \((.*?)\n\);',
        dotAll: true,
      ).firstMatch(sql)!.group(1)!;
      for (final word in ['score', 'rating', 'level', 'category', 'streak']) {
        expect(columns, isNot(contains(word)), reason: word);
      }
    });
  });
}
