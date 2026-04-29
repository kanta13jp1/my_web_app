-- PS#4 S253: 競合3社追加 630→633社 (backblaze/tableplus/dbeaver)
-- SEO: "Backblaze代替"/"TablePlus代替"/"DBeaver代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S253: 競合3社追加 630→633社 (backblaze/tableplus/dbeaver)',
  'comparison_page.dartにbackblaze(低コストクラウドバックアップ/backup/E5232A)/tableplus(モダンDB GUI/dev/007AFF)/dbeaver(OSS万能DB GUI/dev/5B6ABF)の3社追加(630→633社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
