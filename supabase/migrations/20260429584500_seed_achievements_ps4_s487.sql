-- PS#4 S487: 競合3社追加 継続 (hellotalk/tandem/fluentu)
-- SEO: "HelloTalk代替"/"Tandem代替"/"FluentU代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S487: 競合3社追加 (hellotalk/tandem/fluentu)',
  'comparison_page.dartにhellotalk(言語交換SNS150言語翻訳添削音声通話Moments投稿/00C853)/tandem(プロフィールマッチングテキスト/音声/ビデオ添削Proチューター/1565C0)/fluentu(実際の動画インタラクティブ字幕スマートフラッシュカード10言語/0288D1)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
