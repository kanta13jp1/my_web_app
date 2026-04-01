-- Session 432j: ライフスタイル・資産・コンテンツEdge Functions (ファミリー/クラファン/不動産/ポッドキャスト/マインドマップ)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('ファミリー共有管理 Edge Function', 'Apple/Google Family競合: グループ作成、共有カレンダー、支出共有・割り勘、メンバーロール管理(4種)', '2026-04-01'),
  ('寄付・クラウドファンディング Edge Function', 'GoFundMe/CAMPFIRE競合: キャンペーン作成(8カテゴリ)、リワード管理、支援記録、目標達成自動検知、支援者統計', '2026-04-01'),
  ('不動産管理 Edge Function', 'MoneyForward/Suumo競合: 物件登録(7タイプ)、賃貸収支管理(8取引種類)、メンテナンス記録、テナント管理、ROI自動計算', '2026-04-01'),
  ('ポッドキャスト管理 Edge Function', 'Spotify/Apple Podcasts競合: 番組・エピソード管理(12カテゴリ)、購読管理、再生統計、ランキング生成', '2026-04-01'),
  ('マインドマップ・ダイアグラム Edge Function', 'Notion/Miro競合: 6ダイアグラム種類、ノード・エッジ管理、6テンプレート(SWOT/組織図等)、Mermaidエクスポート', '2026-04-01')
ON CONFLICT DO NOTHING;
