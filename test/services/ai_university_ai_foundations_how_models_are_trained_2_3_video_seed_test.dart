import 'dart:io';

import 'package:test/test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260821014235_seed_video-ai-foundations-how-models-are-trained-2-3_ai_university.sql';

  test(
    'AI Foundations 2.3 model training video is seeded as active AI university content',
    () {
      final sql = File(migrationPath).readAsStringSync();

      expect(sql, contains("'openai'"));
      expect(
        sql,
        contains("'video_ai_foundations_how_models_are_trained_2_3'"),
      );
      expect(
        sql,
        contains('https://www.youtube.com/watch?v=5wVvLi-H8PE'),
      );
      expect(sql, contains("'2026-08-21'"));
      expect(sql, contains('事前学習、事後学習、製品体験'));
      expect(sql, contains('一回の会話でモデルが即座に再学習するのではなく'));
      expect(sql, contains('ON CONFLICT (provider, category) DO UPDATE'));
      expect(sql, contains('is_active = EXCLUDED.is_active'));
    },
  );
}
