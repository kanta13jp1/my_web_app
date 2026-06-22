-- Win版#132 part 257 (2026-06-10 / Win Claude): Complete WBS リファラル設計タスク
-- 「リファラル / 紹介プログラム」
--  (task c9a3e346-8cf7-4dc3-8f38-6c4343c4ce87 / category business-marketing / milestone paying-100 /
--   description: Refer-a-friend → 1 ヶ月無料).
--
-- 本タスクは owner_instance='codex' だったが、紹介プログラムの offer/規約/不正対策/KPI 設計は
-- L3 (Win Claude) の architect/marketing-docs レーン ([DYNAMIC-CLAIM] = marketing 引き取り可)。
-- owner も 'win' へ是正。実装タスク f0fd0b22「紹介プログラム実装」(impl / beta / codex) とは
-- 設計/実装の 2 層で分担し、f0fd0b22 は in_progress のまま継続 (本 migration では status を触らない)。
--
-- 重要な実態 (verify 済み): 実装の土台は f0fd0b22 で既に存在 —
--   - DB: referral_codes / referrals (status pending|completed|expired を最初から想定) /
--     referral_tracking (20251106120000_growth_features.sql + 20260402000010_viral_ad_tables.sql)
--   - EF: growth-hub の referral action 群 (ensureReferralCode 8-retry / applyPendingReferral /
--     self-referral no-op / referred_user 冪等) + touch_referral / signup_submit_referral signal
--   - UI: /referral (code capture → apply / UTM 招待リンク / share card)
--   欠けていたのは設計の正本: 「1 ヶ月無料」offer と実装 (500pt 固定・sign-up 即 completed) の
--   不整合解消 / 課金前 fulfillment / activation 条件 / 不正対策 / 規約 / KPI → 本成果物で確立。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/REFERRAL_PROGRAM_DESIGN.md … リファラルプログラム設計の正本 (SSOT)。
--       実在実装の verify 一覧 (§1) + give-get offer 設計と課金前のクレジット累積方式
--       (500pt = Pro 1 ヶ月無料への交換レート清算 / 全数値【CEO確定】= dd9f690b 連動) (§2) +
--       activation 2 段階化 (signed_up → activated / referrals.status 既存 enum で schema 変更ゼロ) (§3) +
--       不正対策 6 項 (実装済 2 + 設計 4 / multi-account 機械検出は意図的 defer) (§4) +
--       規約骨子 8 項 (§5) + K-factor と既存 signal 流用の計測設計 (§6) +
--       f0fd0b22 への実装残 7 件 handoff (§7) + 発効条件 (§8) + Deferred (§9)。
--
-- 完了の定義: 紹介プログラムの「設計・文書化」が成果物。報酬数値・規約発効・公開開始は
-- 【CEO確定】+ f0fd0b22 実装完了後 (本 migration では運用開始を主張しない / honest scope)。
--
-- ai_review_status='approved' を同一 UPDATE で設定 → trigger 回避で status='completed' 確定。
-- Idempotent: 固定値 UPDATE / description・remaining_work append は LIKE guard /
-- achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect / marketing-docs lane / L3) self-authored deliverable. docs/REFERRAL_PROGRAM_DESIGN.md に紹介プログラム設計の正本 (SSOT) を整備。実装土台 (referral_codes/referrals/referral_tracking + growth-hub referral actions + /referral UI + UTM リンク) は f0fd0b22 で実在を verify 済み — 欠けていた設計を確立: 「1 ヶ月無料」offer と現行実装 (500pt 固定・sign-up 即 completed) の不整合を課金前クレジット累積方式 (500pt = Pro 1 ヶ月無料交換 / 数値【CEO確定】) で解消 + activation 2 段階化 (referrals.status 既存 enum 流用で schema 変更ゼロ) + 不正対策 6 項 + 規約骨子 8 項 + K-factor 計測 (既存 signal 流用) + f0fd0b22 への実装残 7 件 handoff + 発効条件。実装は f0fd0b22 (codex / in_progress) で継続し、公開開始は CEO 承認 + activation 実装完了後 (honest scope)。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by Win Claude (part 257). 紹介プログラム設計 SSOT = docs/REFERRAL_PROGRAM_DESIGN.md。残: 報酬数値・cap・activation 閾値の CEO 確定 (§2-3) + 規約条文化承認 (§5) → 実装残 7 件は f0fd0b22 (codex) §7 参照 → 発効は §8 の 4 条件成立後。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: referral program design established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10 (Win Claude part 257): referral program design established at docs/REFERRAL_PROGRAM_DESIGN.md as the SSOT. Verified first what already runs from the implementation task f0fd0b22: referral_codes / referrals / referral_tracking tables, growth-hub referral actions (unique code generation, applyPendingReferral with self-referral guard and one-referral-per-referred-user idempotency), the /referral page with UTM invite links and share card, and funnel signals. What was missing was the design layer, which this doc adds with zero new app development: the gap between the advertised offer (one month free) and the current implementation (flat 500 bonus points granted instantly at sign-up) is resolved via a pre-billing accrual model (points convert to one free Pro month when billing launches; all amounts are CEO-confirmation placeholders tied to pricing task dd9f690b), a two-stage activation (signed_up then activated, reusing the existing referrals.status enum so no schema change), six anti-fraud measures (two already implemented, four designed, mechanical multi-account detection deliberately deferred), an eight-point terms outline, K-factor measurement reusing existing signals only, a seven-item implementation handoff back to f0fd0b22 (codex, stays in_progress), and activation conditions for launch. Honest completion: authoring the design is the deliverable; no program launch or reward fulfillment is claimed. Task claimed codex -> win (referral offer/terms/fraud/KPI design is the L3 lane).'
  END,
  updated_at        = now()
WHERE id = 'c9a3e346-8cf7-4dc3-8f38-6c4343c4ce87';

-- 実装タスク f0fd0b22 へ設計正本 pointer を handoff (status/owner/progress は触らない /
-- codex が次回 pickup 時に §7 の実装残 7 件と着手順を参照できるようにする)
UPDATE public.wbs_tasks
SET
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Design SSOT (2026-06-10 part 257): docs/REFERRAL_PROGRAM_DESIGN.md — 実装残 7 件は §7 (着手順 = activation 2 段階化 → cap/異常検知 → redemption UI)。activation は referrals.status 既存 enum 流用で schema 変更ゼロ (§3)。報酬数値は【CEO確定】待ちのため redemption UI の文言は §2-2 の accrual 表記に従うこと。'
  ),
  updated_at = now()
WHERE id = 'f0fd0b22-e9ba-473e-b6f1-689591f53413'
  AND COALESCE(remaining_work, '') NOT LIKE '%Design SSOT (2026-06-10 part 257)%';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'リファラル / 紹介プログラム設計 v1 — REFERRAL_PROGRAM_DESIGN 確立',
  'docs/REFERRAL_PROGRAM_DESIGN.md を新設。実装タスク f0fd0b22 で実在する土台 (referral_codes / referrals / referral_tracking テーブル + growth-hub の referral action 群 + /referral 画面 + UTM 招待リンク) を verify した上で、欠けていた設計の正本を確立: 「1 ヶ月無料」offer と現行実装 (500pt 固定・sign-up 即 completed) の不整合を課金前クレジット累積方式で解消 (数値は CEO 確定 / 料金プラン dd9f690b 連動) + activation 2 段階化 (signed_up → activated / 既存 status enum 流用で schema 変更ゼロ) + 不正対策 6 項 + 規約骨子 8 項 + K-factor 計測 (既存 signal 流用) + f0fd0b22 への実装残 7 件 handoff + 発効 4 条件。運用開始は claim せず設計のみ完了 (設計シリーズ第 15 弾)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'リファラル / 紹介プログラム設計 v1 — REFERRAL_PROGRAM_DESIGN 確立'
);
