-- WBS Codex takeover: asset management bank CSV import hardening.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: continue the partially
-- started MoneyForward-style asset management task by hardening bank balance
-- imports from Google Sheet CSV and improving the responsive action row.

UPDATE wbs_tasks
SET
  title = '資産管理 (MoneyForward対抗) (Codex引継ぎ)',
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 52),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex hardened Google Sheet CSV balance imports for 三井住友/じぶん銀行, removed the invalid REPLACE_ME URL path, and made the bank import action row responsive.'
  ),
  recovery_plan = concat_ws(
    E'\n',
    NULLIF(recovery_plan, ''),
    'Next: add the official じぶん銀行 sheet GID when available, then persist imported balances with source metadata for MoneyForward parity.'
  ),
  updated_at = now()
WHERE title IN (
  '資産管理 (MoneyForward対抗)',
  '資産管理 (MoneyForward対抗) (Codex引継ぎ)'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '資産管理 銀行CSV取得改善',
  'Codex が資産管理 (MoneyForward対抗) タスクを部分引き継ぎ。GoogleシートCSVからの銀行残高取得を共通処理化し、三井住友/じぶん銀行の取得エラーを明確化、資産入力カードの銀行取得ボタンをモバイルでも折り返せるUIに改善した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
