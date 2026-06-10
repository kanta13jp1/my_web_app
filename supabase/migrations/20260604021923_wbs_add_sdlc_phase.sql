-- Add an SDLC phase axis to WBS tasks.
-- Source: docs/cross-instance-prs/20260603_wbs_sdlc_phase.md

begin;

alter table public.wbs_tasks
  add column if not exists phase text;

comment on column public.wbs_tasks.phase is
  'SDLC phase: planning/design/impl/test/release/ops/maintenance. NULL means unclassified or needs manual review.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wbs_tasks_phase_check'
      and conrelid = 'public.wbs_tasks'::regclass
  ) then
    alter table public.wbs_tasks
      add constraint wbs_tasks_phase_check
      check (
        phase is null
        or phase in (
          'planning',
          'design',
          'impl',
          'test',
          'release',
          'ops',
          'maintenance'
        )
      );
  end if;
end $$;

-- Backfill only categories confirmed from production/public WBS reads.  Leave
-- ambiguous rows NULL so later UI work can classify them intentionally.
update public.wbs_tasks
set phase = 'ops'
where phase is null
  and category in (
    'インフラ・CI/CD',
    'インフラ',
    'Claude Schedule',
    'GitHub Actions',
    '開発自動化',
    'ops'
  );

update public.wbs_tasks
set phase = 'design'
where phase is null
  and category in ('デザインシステム', 'AI Strategy');

update public.wbs_tasks
set phase = 'test'
where phase is null
  and category in ('品質・安定性');

update public.wbs_tasks
set phase = 'impl'
where phase is null
  and category in (
    'AI大学',
    'AI統合',
    'AI Integration',
    'コアSaaS機能',
    'コアSaaS開発',
    'Core SaaS Features',
    'グロース自動化',
    'ユーザー獲得',
    '動画教材'
  );

insert into public.wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  planned_start_date,
  planned_end_date,
  priority,
  estimated_hours,
  remaining_work,
  recovery_plan,
  recovery_planned_at,
  phase
)
select
  v.category,
  v.category_icon,
  v.category_order,
  v.title,
  v.description,
  v.instance,
  v.owner_instance,
  v.status,
  v.progress,
  v.start_date,
  v.end_date,
  v.planned_start_date,
  v.planned_end_date,
  v.priority,
  v.estimated_hours,
  v.remaining_work,
  v.recovery_plan,
  v.recovery_planned_at,
  v.phase
from (
  values
    (
      '企画・要件',
      'P',
      10,
      '[企画] プロダクト要件定義書 (PRD) 整備',
      'L1 Antigravity+Gemini の探索結果を、ペルソナ・KPI・スコープ・非目標まで含むPRDとして固定する。',
      'win',
      'win',
      'pending',
      0,
      date '2026-06-04',
      date '2026-06-14',
      date '2026-06-04',
      date '2026-06-14',
      'high',
      6.0,
      'PRD skeleton, persona, KPI, scope, non-goals, acceptance notes.',
      'Keep the PRD small enough to review weekly; split into feature Issues when scope expands.',
      now(),
      'planning'
    ),
    (
      '企画・要件',
      'P',
      10,
      '[企画] 四半期ロードマップ策定',
      '競合監視・ユーザー要望・WBS進捗を反映し、次四半期の優先順位をSDLC工程別に再配置する。',
      'win',
      'win',
      'pending',
      0,
      date '2026-06-04',
      date '2026-06-21',
      date '2026-06-04',
      date '2026-06-21',
      'medium',
      4.0,
      'Quarterly roadmap draft, risk notes, and WBS phase balance review.',
      'If the roadmap slips, cut low-confidence feature lanes before moving delivery tasks.',
      now(),
      'planning'
    ),
    (
      '設計',
      'D',
      11,
      '[設計] アーキテクチャ判断ログ運用 (ADR)',
      '主要な設計判断をADR化し、NotebookLMとWBSに紐づけて後続実装が迷わない状態にする。',
      'win',
      'win',
      'pending',
      0,
      date '2026-06-04',
      date '2026-06-21',
      date '2026-06-04',
      date '2026-06-21',
      'medium',
      5.0,
      'ADR template, decision log index, and cross-instance handoff convention.',
      'Escalate to Claude architecture review before implementation if competing designs remain.',
      now(),
      'design'
    ),
    (
      '実装',
      'I',
      12,
      '[実装] SDLC別バックログ実装レーン整備',
      'phase列を使って実装タスクを抽出し、Codexが拾いやすい粒度へ分割する。',
      'codex',
      'codex',
      'pending',
      0,
      date '2026-06-04',
      date '2026-06-28',
      date '2026-06-04',
      date '2026-06-28',
      'high',
      6.0,
      'Implementation lane filter, backlog split rule, and owner handoff notes.',
      'If the lane grows too large, split by feature surface and keep one PR per bounded change.',
      now(),
      'impl'
    ),
    (
      'テスト',
      'T',
      14,
      '[テスト] E2E/結合テストカバレッジ整備',
      '主要導線のFlutter testとintegration/E2E確認を工程別に紐づける。',
      'codex',
      'codex',
      'pending',
      0,
      date '2026-06-04',
      date '2026-07-05',
      date '2026-06-04',
      date '2026-07-05',
      'high',
      8.0,
      'Critical journey list, deterministic test command map, and CI evidence notes.',
      'When flakes appear, isolate by route and keep the failing check visible in WBS.',
      now(),
      'test'
    ),
    (
      'リリース',
      'R',
      15,
      '[リリース] リリースチェックリストとロールバック整備',
      'deploy-prod gate、canary確認、rollback runbookを一つのリリース工程として管理する。',
      'codex',
      'codex',
      'pending',
      0,
      date '2026-06-04',
      date '2026-07-12',
      date '2026-06-04',
      date '2026-07-12',
      'high',
      5.0,
      'Release checklist, canary proof, rollback trigger, and version verification notes.',
      'If production verification fails, stop feature merges until the rollback/forward-fix path is decided.',
      now(),
      'release'
    ),
    (
      '運用',
      'O',
      16,
      '[運用] 本番監視・インシデント対応 runbook',
      'cs-check、ci-cd-audit、incident reportを定常運用としてWBSに接続する。',
      'codex',
      'codex',
      'in_progress',
      10,
      date '2026-06-04',
      date '2026-12-31',
      date '2026-06-04',
      date '2026-12-31',
      'high',
      6.0,
      'Operational runbook, escalation paths, and recurring health check evidence.',
      'Keep this lane current through deploy incidents and stale automation audits.',
      now(),
      'ops'
    ),
    (
      '保守',
      'M',
      17,
      '[保守] 依存更新と技術的負債の棚卸し',
      'Dependabot、週次vendor digest、stale docs/code削除を保守工程として運用する。',
      'codex',
      'codex',
      'pending',
      0,
      date '2026-06-04',
      date '2026-12-31',
      date '2026-06-04',
      date '2026-12-31',
      'medium',
      4.0,
      'Dependency review queue, stale artifact policy, and cleanup cadence.',
      'If maintenance competes with urgent product work, keep security and deploy blockers first.',
      now(),
      'maintenance'
    )
) as v(
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  planned_start_date,
  planned_end_date,
  priority,
  estimated_hours,
  remaining_work,
  recovery_plan,
  recovery_planned_at,
  phase
)
where not exists (
  select 1
  from public.wbs_tasks as existing
  where existing.title = v.title
    and existing.instance = v.instance
);

insert into public.development_achievements (title, description, completed_at)
values (
  'Codex #1: WBS SDLC phase axis migration',
  'Added public.wbs_tasks.phase with seven SDLC values, backfilled confirmed WBS categories, and seeded one or more tasks for every phase from the Win Claude part 240d handoff.',
  now()
)
on conflict do nothing;

commit;
