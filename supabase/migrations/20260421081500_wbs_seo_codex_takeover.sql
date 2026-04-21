-- Codex takeover: SEO improvement (sitemap and route meta tags).
--
-- Only the SEO task Codex actually started is moved to the Codex owner.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 85),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex added route-specific SEO meta/canonical handling for public discovery pages, expanded the SEO shell internal links, refreshed sitemap.xml with 2026-04-21 public routes, and normalized robots.txt crawl rules.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'Next: submit the refreshed sitemap in Google Search Console, monitor indexed coverage for /project-gantt and AI University routes, and add server-rendered static shells if SPA indexing remains weak.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'SEO改善 (sitemap・meta tags)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'SEO sitemap and route meta tags Codex takeover',
  'Codex が SEO改善 (sitemap・meta tags) を一時引き継ぎ、主要公開ルートの route-specific meta/canonical、SEO shell 内部リンク、2026-04-21 sitemap 拡充、robots.txt 正規化を実施。WBS owner を Codex に変更し、進捗を 85% に更新した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
