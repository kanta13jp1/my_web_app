import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260828221715_seed_video-claude-academy-overview_ai_university.sql';

  test(
    'Claude Academy overview video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(sql, contains("'video_claude_academy_overview'"));
      expect(sql, contains('https://www.youtube.com/watch?v=7tsldHpEzTo'));
      expect(sql, contains("'2026-08-28'"));
      expect(sql, contains('Claude Academyの主要な学習ルート'));
      expect(sql, contains('Delegation、Description、Discernment、Diligence'));
      expect(sql, contains('Anthropicによる公式動画、公式翻訳、公式見解ではありません'));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
