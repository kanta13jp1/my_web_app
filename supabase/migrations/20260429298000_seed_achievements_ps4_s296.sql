-- PS#4 S296: 競合3社追加 759→762社 (whova/creator-iq/aspire-io)
-- SEO: "Whova代替"/"Creator.IQ代替"/"Aspire代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S296: 競合3社追加 759→762社 (whova/creator-iq/aspire-io)',
  'comparison_page.dartにwhova(受賞歴イベント管理ネットワーキング/events/3E7EE8)/creator-iq(エンタープライズインフルエンサーマーケ/influencer/6B48FF)/aspire-io(クリエイターマーケットプレース管理/influencer/FF5F5F)の3社追加(759→762社)。sitemap 805 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
