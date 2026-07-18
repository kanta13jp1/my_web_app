-- Scheduled Daily (2026-07-18 01:00 UTC) — daily-development autonomous cron:
-- Records fixing two duplicate provider ids in the AI大学 registry
-- (kAiProviderRegistry) plus a regression guard test and a reusable
-- "duplicate entries in a const List are a silent bug" blog draft.
-- Ran in an isolated worktree off origin/main (the main checkout was parked
-- on a foreign codex WIP branch, so report-only/no-touch discipline applied
-- to that branch; real work happened on a fresh daily/ worktree instead).

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Daily 2026-07-18: AI大学 provider registry の重複 id 2 件を修正 + 一意性回帰ガード',
  'AI大学 プロバイダーレジストリ (lib/models/ai_provider_registry.dart / const List<AiProviderEntry> kAiProviderRegistry) に baseten と scale_ai が各 2 回定義されていた重複バグ (総数 223 / ユニーク 221) を修正した。Dart は Map リテラルの重複キーは analyzer (equal_keys_in_map) で弾くが、List の重複要素は完全に合法で素通りするため、id で一意性を暗黙に期待していた運用前提とのギャップで発生していた。実害は firstWhere 系の先勝ちで、後から URL と資金調達メモを足したリッチな新エントリが表示されない状態。修正方針は「削除」ではなく「正典へのマージ」— セクション分類と tier フィールドを持つ先頭の正典エントリに、重複側の URL (baseten.co / scale.com) とリッチな note をマージし、後から一括追加された重複エントリ 2 件を削除。情報量とセクション構成を両立させた。再発防止として test/models/ai_provider_registry_test.dart を新設し、Set.add ベースの id 一意性テスト + 全エントリの id/displayName 非空テストを追加 (2 tests all green)。flutter analyze は No issues found! / flutter test 全緑で検証済み。学びを JA 技術ブログ下書き (2026-07-18-dart-const-list-duplicate-guard.md) に「言語が保証しない不変条件はテストで固定する」一般則として整理。VIBE_CODING_PRINCIPLES (責任ある AI 自動化 / bounded scope) + AI_DEV_PRINCIPLES (deny-by-default / safe defaults) + INDIE_DEV_VELOCITY (小さく確実に shipping) を強化。日次 cron の作法 (sequential Bash / origin/main 由来の隔離 worktree / foreign codex WIP ブランチには非干渉) を維持。',
  '2026-07-18'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Daily 2026-07-18: AI大学 provider registry の重複 id 2 件を修正 + 一意性回帰ガード'
);
