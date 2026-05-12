-- PS#4 S271: 競合3社追加 684→687社 (workato/tray-io/pabbly)
-- SEO: "Workato代替"/"Tray.io代替"/"Pabbly代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S271: 競合3社追加 684→687社 (workato/tray-io/pabbly)',
  'comparison_page.dartにworkato(エンタープライズiPaaS/automation/00C2A2)/tray-io(低コード統合自動化/automation/6200EA)/pabbly(Zapier代替安価自動化/automation/E91E63)の3社追加(684→687社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
