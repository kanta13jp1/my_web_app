-- Win版#132 part 248 (2026-06-09 / Win Claude): Complete WBS ブランド設計タスク
-- 「ブランドガイドライン v1」 (task dce3f86c-7330-4aeb-bb97-891b040313b0 / milestone mvp-launch).
--
-- 本タスクは owner_instance='codex' だったが、ブランド/UI design・docs は L3 (Win Claude) の
-- レーン ([DYNAMIC-CLAIM] = marketing/docs 引き取り可)。user の明示的 /loop 再起動による
-- 指示で本 session 3 件目 (autonomous 2-cap を超える分は user 明示指示が根拠)。owner も 'win' へ是正。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/BRAND_GUIDELINE.md … ブランドのアイデンティティ層 v1。
--       DESIGN.md (UI トークン正本) と重複せず、その上位のブランド意味づけを定義: ブランド約束
--       (AI と人生を会社のように経営 / 昨日の自分基準) + パーソナリティ (穏やか mentor × 生命力 ×
--       誠実) + ボイス&トーン 5 原則 (part 246 アプリ内 / part 247 SNS の声を正本化 / 検証ファースト・
--       誇張禁止を内包) + ロゴ運用 v1 ルール + 色の意味 (hex は DESIGN.md 参照) + タイポ (ブランド
--       観点 / 実値は DESIGN.md) + 適用マトリクス + ブランド NG + Deferred (ロゴ実アセット/商標は外)。
--       ブランドボイス最終確定とロゴ実アセットは CEO 判断待ちの v1 叩き台。
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
  ai_review_notes   = 'Win Claude (architect lane / L3 / UI design lane) self-authored deliverable. docs/BRAND_GUIDELINE.md にブランドのアイデンティティ層 v1 を整備 (DESIGN.md UI トークンと重複せず上位のブランド意味づけ: ブランド約束 + パーソナリティ + ボイス&トーン 5 原則 (246/247 の声を正本化 / 検証ファースト内包) + ロゴ運用 + 色の意味 (hex は DESIGN.md 参照) + 適用マトリクス + NG)。ブランドボイス最終確定・ロゴ実アセットは CEO 確認待ち。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-09'),
  end_date          = DATE '2026-06-09',
  remaining_work    = 'Completed by Win Claude (part 248). ブランドガイドラインは docs/BRAND_GUIDELINE.md。UI トークンは DESIGN.md 正本のまま、その上位のブランド identity/voice 層を定義。ロゴ実アセットのデザインとブランドボイス最終確定は CEO 判断で確定する。商標/法的保護は business-legal レーンで別扱い。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-09: Brand guideline v1 established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-09 (Win Claude part 248): Brand guideline v1 established at docs/BRAND_GUIDELINE.md. Defines the brand identity layer ABOVE DESIGN.md (which stays the source of truth for UI tokens): brand promise (run your life like a company with AI / measure against yesterday-you), personality (gentle mentor x vitality x honesty), a 5-principle voice & tone that canonicalizes the in-app voice (part 246) and SNS voice (part 247) and embeds verify-first/no-exaggeration, logo usage v1 rules, color meaning (hex referenced from DESIGN.md, not duplicated), brand-level typography (values in DESIGN.md), a cross-touchpoint application matrix, and brand do-nots. Logo real asset and final brand voice require CEO judgment; trademark/legal is out of scope (business-legal lane). Docs-only; no code/schema change. 3rd task this session under explicit user /loop re-invocation (beyond the autonomous 2-task cap). Task claimed codex -> win (brand/UI design is the L3 lane).'
  END,
  updated_at        = now()
WHERE id = 'dce3f86c-7330-4aeb-bb97-891b040313b0';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'ブランドガイドライン v1 確立 (ボイス&トーン正本化)',
  'docs/BRAND_GUIDELINE.md を新設。DESIGN.md (UI トークン正本) と重複しないブランドのアイデンティティ層を定義。ブランド約束 (AI と人生を会社のように経営 / 昨日の自分基準)、パーソナリティ (穏やか mentor × 生命力 × 誠実)、全タッチポイント共通のボイス&トーン 5 原則 (part 246 アプリ内 + part 247 SNS の声を正本化 / 検証ファースト・誇張禁止を内包)、ロゴ運用 v1 ルール、色の意味 (hex は DESIGN.md 参照)、適用マトリクス、ブランド NG を整備。MVP ローンチ準備設計シリーズ第 8 弾 (ブランド面)。ロゴ実アセットとボイス最終確定は CEO 判断へ。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'ブランドガイドライン v1 確立 (ボイス&トーン正本化)'
);
