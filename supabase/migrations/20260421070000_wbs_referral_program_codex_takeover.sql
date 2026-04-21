-- Codex takeover: referral program implementation.
--
-- Only the task Codex actually started is moved to the Codex owner.
-- This slice connects the referral UI/service path to the real
-- referral_codes/referrals tables through growth-hub.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 25),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex connected referral.list to referral_codes/referrals, aligned /referral with GrowthMissionService, and standardized invite links on /referral with UTM tracking.',
    'Next: add reward redemption UI, leaderboard/ranking view, and production smoke test for referred sign-up attribution.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'If referral attribution fails in production, inspect growth-hub referral.list pendingCode handling and fallback to direct referrals table insert from GrowthMissionService.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = '紹介プログラム実装'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Referral program real table integration',
  'Codex が紹介プログラム実装を一時引き継ぎ、growth-hub の referral.list/create を referral_codes/referrals 実テーブルへ接続。/referral 画面を GrowthMissionService ベースに更新し、紹介コード・紹介実績・UTM付き招待リンクの導線を統一した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
