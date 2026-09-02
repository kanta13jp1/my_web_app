import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260821084232_seed_video_ai_foundations_trusted_sources_2_4.sql';

  test(
    'AI Foundations 2.4 trusted sources video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(
        sql,
        contains("'video_ai_foundations_trusted_sources_2_4'"),
      );
      expect(
        sql,
        contains('https://www.youtube.com/watch?v=VqCeYy7yg28'),
      );
      expect(sql, contains("'2026-08-21'"));
      expect(sql, contains('信頼できる情報源を先に確認し'));
      expect(sql, contains('事実・出典・最終判断の三点を確認'));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
