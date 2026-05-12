-- PS#4 S490: 競合3社追加 継続 (remnote/supernotes/capacities)
-- SEO: "RemNote代替"/"Supernotes代替"/"Capacities代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S490: 競合3社追加 (remnote/supernotes/capacities)',
  'comparison_page.dartにremnote(ノートSRS統合PDF注釈知識グラフポータル双方向リンク/3F51B5)/supernotes(カード型ノートコラボ双方向リンクリアルタイム共有軽量Markdown/FF6B6B)/capacities(オブジェクト型PKMタイプ別管理双方向リンクAI統合/7C4DFF)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
