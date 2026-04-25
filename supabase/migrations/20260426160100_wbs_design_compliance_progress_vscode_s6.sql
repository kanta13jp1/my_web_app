-- VSCode版 S6: DESIGN.md全ページ準拠 — 9ページ dark-mode 対応完了
-- Task 32731c06: progress 68% → 75%
-- commit 7e69082c: 9 pages fixed (asset_management, emergency_meeting,
--   morning_briefing, money_forward, wip_limit, weekly_slip_report,
--   team_chat, language_learning, agent_org)

update public.wbs_tasks
set
  progress       = 75,
  status         = 'in_progress',
  instance       = 'vscode',
  owner_instance = 'vscode',
  updated_at     = now()
where id::text like '32731c06%'
  and progress < 75;
