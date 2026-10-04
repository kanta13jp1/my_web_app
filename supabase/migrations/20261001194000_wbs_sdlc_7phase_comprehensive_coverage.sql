-- Antigravity / 2026-10-01.
-- WBS Comprehensive SDLC 7-Phase Coverage: Planning, Design, Impl, Test, Release, Ops, Maintenance.
-- Guarantees that every SDLC phase has dedicated, non-empty, actionable tasks in WBS.
-- Deduplication protected via NOT EXISTS guards.
-- nocheck: time-relative

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[企画] Antigravity+Geminiを活用した生成UI/UXプロトタイプ高速探索と要求仕様定義',
  'Planning & Exploration',
  'in_progress',
  20,
  'high',
  'antigravity',
  'planning',
  'Antigravityのgenerative_uiスキルやマルチモーダル分析を駆使し、新規機能のUIモックアップおよび要求仕様を高速検証・策定する。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[企画] Antigravity+Geminiを活用した生成UI/UXプロトタイプ高速探索と要求仕様定義'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[企画] 24大AI/テクノロジー公式動向の週次自動インテークとプロダクト企画バックログ評価',
  'Planning & Exploration',
  'pending',
  0,
  'medium',
  'antigravity',
  'planning',
  'Anthropic, OpenAI, Google, Microsoft, Meta, DeepSeek等の最新機能・APIリリースを定期インテークし、新規機能候補を自動起票・評価する。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[企画] 24大AI/テクノロジー公式動向の週次自動インテークとプロダクト企画バックログ評価'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[設計] 3レーン協調(Antigravity/Codex/Claude Code)によるクロスエージェント設計レビュー自動化',
  'Architecture & Design',
  'in_progress',
  40,
  'high',
  'claude',
  'design',
  'L1(企画/UI探索)・L2(実装/テスト)・L3(設計/アーキレビュー)の引継ぎ契約（Delegation Packet）とインターフェース整合性を担保する。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[設計] 3レーン協調(Antigravity/Codex/Claude Code)によるクロスエージェント設計レビュー自動化'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[設計] 外部API/SaaS連携(Stripe, Notion, Slack, Discord, FireCrawl)の耐障害・Fail-Openアーキテクチャ設計',
  'Architecture & Design',
  'pending',
  0,
  'medium',
  'claude',
  'design',
  '外部依存サービスの障害時フォールバックおよびデータ整合性を保証するアーキテクチャ設計。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[設計] 外部API/SaaS連携(Stripe, Notion, Slack, Discord, FireCrawl)の耐障害・Fail-Openアーキテクチャ設計'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[実装] 最新AIモデル(GPT-6.1 / Claude Sonnet 5.5 / Gemini 3.1 Pro)の推論APIハイブリッドルーティング実装',
  'Core Implementation',
  'in_progress',
  30,
  'high',
  'codex',
  'impl',
  '複数プロバイダの最新モデルを動的・コスト効率的に切り替えるエッジ関数およびフォールバックルーティングの実装。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[実装] 最新AIモデル(GPT-6.1 / Claude Sonnet 5.5 / Gemini 3.1 Pro)の推論APIハイブリッドルーティング実装'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[テスト] Playwright / Chrome DevTools によるFlutter Web E2Eシナリオ・ビジュアルリグレッション自動テスト拡充',
  'Testing & QA',
  'in_progress',
  50,
  'high',
  'codex',
  'test',
  '主要ユーザージャーニー（認証、資産管理、AI大学、課金フロー）のヘッドレスブラウザE2Eテスト網羅。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[テスト] Playwright / Chrome DevTools によるFlutter Web E2Eシナリオ・ビジュアルリグレッション自動テスト拡充'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[リリース] GitHub Actions クラウドファーストCI/CDによる自動ビルド・検証・Firebase/Supabase本番無停止デプロイ',
  'Release & Deployment',
  'in_progress',
  70,
  'critical',
  'codex',
  'release',
  'ローカルリソース枯渇時でもクラウド上で完全再現可能なビルド・デプロイ・ロールバック自動化。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[リリース] GitHub Actions クラウドファーストCI/CDによる自動ビルド・検証・Firebase/Supabase本番無停止デプロイ'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[運用] 24大テクノロジープラットフォーム公式ドキュメント・Changelog定常監視と自動ダイジェスト生成',
  'Operations & Monitoring',
  'in_progress',
  60,
  'high',
  'antigravity',
  'ops',
  '週次でのベンダー更新差分抽出、重要度判定、Issue自動化の定常自律運用。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[運用] 24大テクノロジープラットフォーム公式ドキュメント・Changelog定常監視と自動ダイジェスト生成'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[保守] 古いドキュメント(superseded/重複/dead-link)の定期スキャンと安全な自動削除・インデックス同期',
  'Maintenance & Hygiene',
  'in_progress',
  50,
  'high',
  'claude',
  'maintenance',
  'ドキュメント肥大化を防ぎ、常に最新の単一情報源(SSOT)を維持する自動メンテナンス。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[保守] 古いドキュメント(superseded/重複/dead-link)の定期スキャンと安全な自動削除・インデックス同期'
);

INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, owner_instance, phase, description, created_at, updated_at
)
SELECT
  '[保守] ローカル・リモートリソース衛生管理(Disk Hygiene Cascade / Worktree Pruning)の自動化',
  'Maintenance & Hygiene',
  'pending',
  0,
  'high',
  'codex',
  'maintenance',
  '肥大化したworktreeやキャッシュを安全に整理し、ディスク空き容量を確保する定常メンテナンス。',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[保守] ローカル・リモートリソース衛生管理(Disk Hygiene Cascade / Worktree Pruning)の自動化'
);
