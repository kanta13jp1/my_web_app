-- PS#4 S526: 競合3社追加 継続 (clicky/piwik-pro/usertesting)
-- SEO: "Clicky代替"/"Piwik PRO代替"/"UserTesting代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S526: 競合3社追加 (clicky/piwik-pro/usertesting)',
  'comparison_page.dartにclicky(リアルタイムウェブ分析・訪問者単位追跡・ヒートマップ・スパムフィルター・軽量シンプル/00A651)/piwik-pro(プライバシー重視分析スイート・GDPR/HIPAA・Cookie不要モード・CDP/1A6496)/usertesting(ユーザーリサーチプラットフォーム・20万人パネル・動画UX・AIインサイト/FF6320)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
