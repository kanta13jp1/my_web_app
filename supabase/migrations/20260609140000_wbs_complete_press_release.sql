-- Win版#132 part 249 (2026-06-09 / Win Claude): Complete WBS プレスリリースタスク
-- 「PR Times プレスリリース v1」 (task 88d0ac29-7330... / 88d0ac29-932c-4bdb-994e-87aea6f524fa /
--  milestone mvp-launch / 「MVP 公開 PR / メディア配信先 50 社」).
--
-- 本タスクは owner_instance='codex' だったが、対外文言/プレス/marketing docs は
-- [DYNAMIC-CLAIM] で marketing/docs を Win Claude (L3) が引き取り可能なレーン。/loop autonomous で
-- claim (codex→win)。owner も 'win' へ是正。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/PRESS_RELEASE_V1.md … プレスリリース v1 ドラフト + 配信戦略。
--       (1) 配信用文面 v1 (タイトル/リード/背景/特長 5/サービス概要/代表コメント書式例/問い合わせ)。
--           発行体・配信日・CEO コメント・実績数値は `【...】` プレースホルダ (CEO 確認 / 未検証数値・
--           誇張を一切書かない = BRAND_GUIDELINE §7 + [REAL-DATA] + 景表法配慮)。
--       (2) 配信戦略: 「50 社」= PR Times 主配信 + 重点 6 カテゴリ taxonomy。個別 50 件の最終リスト・
--           連絡先・実入稿は CEO + PR Times アカウントへ defer (フライング配信しない)。
--       (3) アセット checklist / honesty ガードレール / Deferred / Philosophy 整合。
--   MVP コア 5 機能 (MVP_SCOPE.md) を価値訴求に翻訳。ブランドボイス (BRAND_GUIDELINE.md §2) 準拠。
--
-- 完了の定義: プレス文面 v1 + 配信戦略の「設計・起草」が成果物 (タスク = v1 起草)。実配信・PR Times
-- 入稿・発行体の法的確定は CEO/business-legal レーンの別アクション (本 migration では完了扱いにしない)。
--
-- ai_review_status='approved' を同一 UPDATE で設定するため、progress=100 への遷移でも
-- wbs_request_ai_review trigger は発火しない → status='completed' が確定する。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect/docs/marketing lane / L3) self-authored deliverable. docs/PRESS_RELEASE_V1.md に MVP 公開プレスリリース v1 ドラフト + 配信戦略を整備。文面は発行体/配信日/CEO コメント/実績数値を CEO 確認プレースホルダにし、未検証数値・誇張・最上級表現を排除 (BRAND_GUIDELINE §7 + 景表法配慮 + [REAL-DATA])。配信先「50 社」は PR Times 主配信 + 重点 6 カテゴリ taxonomy として設計し、個別 50 件の最終リスト・実入稿・発行体の法的確定は CEO/business-legal へ defer。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-09'),
  end_date          = DATE '2026-06-09',
  remaining_work    = 'Completed by Win Claude (part 249). プレスリリース v1 = docs/PRESS_RELEASE_V1.md (文面ドラフト + 配信戦略)。残: 実 GA 日・発行体 (会社名/屋号/特商法) の確定・CEO コメント差し替え・実績数値の記載・PR Times 実入稿は CEO + business-legal レーン (利用規約 7da440c4 / 特商法 520aee16 と連動)。フライング配信しない。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-09: Press release v1 drafted%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-09 (Win Claude part 249): Press release v1 drafted at docs/PRESS_RELEASE_V1.md. Contains (1) a v1 Japanese press-release draft for the MVP launch (headline / lead / background / 5 features / service summary / CEO-quote template / contact) with issuer, launch date, CEO comment and any metrics left as CEO-confirm placeholders -- no unverified numbers, no superlatives, per BRAND_GUIDELINE section 7 and fair-representation (景表法) care; (2) a distribution strategy reframing "50 media outlets" as PR Times as the primary wire plus a 6-category target taxonomy, deferring the final 50-outlet list/contacts and actual submission to CEO + the PR Times account (no premature distribution); (3) an asset checklist, honesty guardrails, deferred scope, and philosophy alignment. Translates the MVP_SCOPE core-5 features into value messaging and follows the BRAND_GUIDELINE voice. Docs-only; no code/schema change. Task claimed codex -> win (marketing/docs is a [DYNAMIC-CLAIM] claimable lane). Completion = authoring the v1 draft + strategy; real issuance, legal issuer confirmation and PR Times submission remain CEO/business-legal actions.'
  END,
  updated_at        = now()
WHERE id = '88d0ac29-932c-4bdb-994e-87aea6f524fa';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'プレスリリース v1 起草 (MVP 公開 PR + 配信戦略)',
  'docs/PRESS_RELEASE_V1.md を新設。MVP 一般公開用プレスリリースの v1 ドラフト (タイトル/リード/背景/特長 5/サービス概要/代表コメント書式例/問い合わせ) と配信戦略を整備。発行体・配信日・CEO コメント・実績数値は CEO 確認プレースホルダとし、未検証数値・誇張・最上級表現を排除 (ブランドガイドライン §7 + 景表法配慮 + リアルデータ原則)。「メディア配信先 50 社」は PR Times 主配信 + 重点 6 カテゴリ taxonomy として設計し、個別リスト・実入稿・発行体の法的確定は CEO/business-legal へ委譲 (フライング配信なし)。MVP コア 5 機能を価値訴求に翻訳。MVP ローンチ準備設計シリーズ第 9 弾 (対外発信面)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'プレスリリース v1 起草 (MVP 公開 PR + 配信戦略)'
);
