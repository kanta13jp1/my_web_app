-- daily-development (scheduled) 2026-10-07: 仮想AI組織ページの行き止まり (エージェント登録経路なし / 入れ子 metadata 未読 / 入力を捨てるタスク割振り) を解消した実績を記録

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '仮想AI組織ページのエージェント登録を実装済みAPIへ接続',
  '/virtual-organization は三重の行き止まりだった。(1) ai-hub の agent.create は実装済みなのに UI からの実行経路が無く、エージェントを1件も登録できない。(2) org.get は hub_data 行 ({id, metadata, created_at}) を返すのに画面は flat キーを読んでおり、登録済みでも全行が「Agent N / 役割なし」に化ける。(3)「タスク割振り」は文章を入力させた後「準備中です」と表示して入力を捨てる。エージェント登録ダイアログを追加して agent.create へ接続し、解析を純データモデル VirtualOrganization / VirtualOrgAgent に移して部署ごとの人数も実データから数えるようにした。agent.run は記録を積むだけで読み出しも実行も存在しないため接続せず、タスクタブは「自動割り振りは未提供」と明示する表示に置き換えた (成功を装わない)。EF 側は無検証で保存するため名前必須・長さ上限の検証を VirtualOrgAgentDraft に置き、送信 body を一覧モデルで読み戻す往復テストとダイアログの widget テストを追加。サーバー側の変更は無し。',
  '2026-10-07'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '仮想AI組織ページのエージェント登録を実装済みAPIへ接続'
);
