import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260823171242_seed_video-ai-foundations-check-in-2-6_ai_university.sql';

  test(
    'AI Foundations 2.6 check-in video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(sql, contains("'video_ai_foundations_check_in_2_6'"));
      expect(sql, contains('https://www.youtube.com/watch?v=vLTQ_iJuhho'));
      expect(sql, contains("'2026-08-23'"));
      expect(sql, contains('生成・根拠づけ・確認の三段階'));
      expect(sql, contains('採用・修正・再実行のどれにするか'));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
