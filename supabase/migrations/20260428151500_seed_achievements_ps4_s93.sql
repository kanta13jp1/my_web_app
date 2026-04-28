-- PS#4 S93: vs-*ページに全174社ランドスケープリンク追加
-- 関連比較セクション末尾に /competitors hub へのナビリンクを追加
-- 内部リンク強化 + UX 改善

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S93: vs-*全174社ページに/competitorsハブリンク追加',
  '各vs-*比較ページの「他の比較ページも見る」セクション末尾に「全174社の競合ランドスケープを見る →」ボタンを追加。/competitorsページへの内部リンクを全174ページから張ることでSEO内部リンク強化。grid_view_roundedアイコン+サーフェスカードデザインでデザインシステム準拠。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
