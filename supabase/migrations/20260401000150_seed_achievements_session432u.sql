-- Session 432u: Edge Functions 211-215 (dns-domain-manager, affiliate-marketing, virtual-pet, ar-navigation, ai-image-generator)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('ドメイン・DNS管理', 'ドメイン登録・DNSレコード管理・SSL証明書監視のEdge Function実装', '2026-04-01'),
  ('アフィリエイトマーケティング', 'アフィリエイトリンク・クリック/コンバージョン追跡・報酬計算のEdge Function実装', '2026-04-01'),
  ('バーチャルペット', '8種ペット育成・エサ/アクティビティ・レベルアップ・リーダーボードのEdge Function実装', '2026-04-01'),
  ('ARナビゲーション', 'ルート管理・ARマーカー・歩数/移動記録・スポット発見のEdge Function実装', '2026-04-01'),
  ('AI画像生成', 'プロンプト管理・ギャラリー・6テンプレート・10スタイル・日次制限のEdge Function実装', '2026-04-01')
ON CONFLICT DO NOTHING;
