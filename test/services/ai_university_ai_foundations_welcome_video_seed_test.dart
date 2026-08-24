import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260818010937_seed_video-openai-ai-foundations-welcome_ai_university.sql';

  test(
    'OpenAI AI Foundations welcome video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(sql, contains("'video_openai_ai_foundations_welcome'"));
      expect(
        sql,
        contains('https://www.youtube.com/watch?v=yGCLS7EW91A'),
      );
      expect(sql, contains("'2026-08-18'"));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
