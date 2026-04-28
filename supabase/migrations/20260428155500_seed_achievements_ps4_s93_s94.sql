-- PS#4 S93: vs-*ページに全174社ランドスケープリンク追加
-- PS#4 S94: /competitors 全社クリック可能化 (「準備中」スナックバー削除)

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S93-S94: /competitorsハブリンク追加 + 全社クリック可能化',
  'S93: 各vs-*比較ページ関連比較セクション末尾に「全174社の競合ランドスケープを見る→」ボタン追加(SEO内部リンク+UX改善)。S94: /competitorsページで旧21社のみ遷移可能だったバグ修正→全社が/vs-*ページに遷移可能。未使用_known21セット・knownパラメータ削除。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
