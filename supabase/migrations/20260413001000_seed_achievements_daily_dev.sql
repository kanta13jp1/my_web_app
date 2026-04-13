-- daily-development 2026-04-13: Slack統合 + AI大学リマインダーバッチ + ノートエディタタブブロック

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'ノートエディタ /tabs コマンド追加',
    'Notion 3.4 タブブロック機能パリティ実装。/tabs コマンドで3タブのMarkdownテンプレートを挿入。スラッシュコマンドヘルプにも追記。',
    '2026-04-13'
  ),
  (
    'AI大学 Qwen + Moonshot AI 追加 (40-41社目)',
    'Alibaba Cloud Qwen (DashScope API / Qwen2.5-72B) と Moonshot AI Kimi (128K コンテキスト) を追加。AI大学 41社体制完成。',
    '2026-04-13'
  ),
  (
    'tools-hub Slack統合 (slack.post / slack.search)',
    'SLACK_WEBHOOK_URL 経由のメッセージ投稿と SLACK_BOT_TOKEN 経由の検索機能を tools-hub EF に追加。Slack MCP 公開に対応。',
    '2026-04-13'
  ),
  (
    'AI大学 学習リマインダーバッチ定期実行設定',
    'daily-report.yml に Step5.5 を追加。3日以上未学習ユーザーへ schedule-hub reminders.study アクション経由でリマインダー送信を毎日自動化。',
    '2026-04-13'
  )
ON CONFLICT DO NOTHING;
