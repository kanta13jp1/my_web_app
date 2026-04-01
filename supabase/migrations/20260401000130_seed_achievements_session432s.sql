-- Session 432s: Edge Functions 201-205 (loyalty-points, live-streaming, geo-checkin, social-stories, encrypted-messaging)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('ロイヤルティポイント', 'ポイント付与/消費・5段階ランク(ブロンズ→ダイヤモンド)・特典交換・リーダーボードのEdge Function実装', '2026-04-01'),
  ('ライブストリーミング', '配信管理・リアルタイムチャット・視聴者分析・スケジュール配信のEdge Function実装', '2026-04-01'),
  ('位置情報チェックイン', 'スポット登録・チェックイン・レビュー・近距離検索(Haversine)・ランキングのEdge Function実装', '2026-04-01'),
  ('ソーシャルストーリーズ', '24時間限定投稿・7種リアクション・投票・ハイライト保存のEdge Function実装', '2026-04-01'),
  ('暗号化メッセージング', 'チャンネル管理・メッセージ自動削除・既読管理・ファイル共有のEdge Function実装', '2026-04-01')
ON CONFLICT DO NOTHING;
