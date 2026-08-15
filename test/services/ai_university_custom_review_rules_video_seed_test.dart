import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260814222735_seed_video-codex-custom-code-review-rules_ai_university.sql';

  test(
    'Codex custom review rules video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(sql, contains("'video_codex_custom_code_review_rules'"));
      expect(
        sql,
        contains('https://www.youtube.com/watch?v=rmaPMyKYZXQ'),
      );
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
