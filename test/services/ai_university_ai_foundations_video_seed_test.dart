import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260815162113_seed_video-openai-ai-foundations_ai_university.sql';

  test(
    'OpenAI AI foundations video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(sql, contains("'video_openai_ai_foundations'"));
      expect(sql, contains('https://www.youtube.com/watch?v=yAbco3K_TLQ'));
      expect(sql, contains("'2026-08-15'"));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
