-- WBS 既存 'all' タスクの個別 reassign (Win版#131 part 16)
--
-- 直近の本番 UI で 'ALL' 表示が残っているタスク群を担当 instance 個別に再分類:
-- (これらは wbs.add_task で他 instance が追加した default='all' タスク)

UPDATE wbs_tasks SET instance = 'win',  owner_instance = 'win'
  WHERE instance = 'all' AND title LIKE '%死んでた機能%';

UPDATE wbs_tasks SET instance = 'ps1',  owner_instance = 'ps1'
  WHERE instance = 'all' AND (
    title LIKE '%Rule17%' OR
    title LIKE '%deploy-prod 成功率%' OR
    title LIKE '%BYPASS_RULES%'
  );

UPDATE wbs_tasks SET instance = 'win',  owner_instance = 'win'
  WHERE instance = 'all' AND title LIKE '%EFハードキャップ%';

UPDATE wbs_tasks SET instance = 'ps2',  owner_instance = 'ps2'
  WHERE instance = 'all' AND title LIKE '%orphan branch%';

UPDATE wbs_tasks SET instance = 'ps5',  owner_instance = 'ps5'
  WHERE instance = 'all' AND title LIKE '%cs-check%';

-- ai-hub 100社系 → win (PSもサブ)
UPDATE wbs_tasks SET instance = 'win',  owner_instance = 'win'
  WHERE instance = 'all' AND (
    title LIKE '%AI大学%' OR
    title LIKE '%AIプロバイダー%'
  );

-- 競合関連 → ps4
UPDATE wbs_tasks SET instance = 'ps4', owner_instance = 'ps4'
  WHERE instance = 'all' AND (
    title LIKE '%競合%' OR
    title LIKE '%MoneyForward%' OR
    title LIKE '%Notion%' OR
    title LIKE '%Asana%'
  );

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS legacy ALL タスク個別 reassign',
  '本番 UI で ALL 表示が残っていた legacy タスク (死んでた機能/Rule17/EF/deploy-prod/orphan/cs-check/AI大学/競合関連) を担当 instance に個別 reassign。Win版#131 part 16。',
  '2026-04-20'
)
ON CONFLICT DO NOTHING;
