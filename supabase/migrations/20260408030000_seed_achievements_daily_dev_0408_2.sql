-- daily-development 2026-04-08 (自動): X投稿通知 + カタログ拡張

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'ギター録音X自動投稿 成功通知UI追加',
    '録音保存後にバックエンドでX自動投稿が成功した場合、青色スナックバーで「録音を保存し、Xに自動投稿しました！」を通知。xPostedフラグをEdge Functionレスポンスから取得してUIに反映。バイラルパイプラインの完成度向上。',
    '2026-04-08'
  ),
  (
    'ホームカタログ AI要約・収益予測・天気ウィジェット追加',
    'home_tool_catalog.dartに ai-summarizer / revenue-forecaster / weather-widget の3ページを登録。業務メニューから検索・ナビゲーション可能に。EdgeFunctionSummaryCardのルート参照も /ai-summarizer / /revenue-forecaster / /weather-widget に更新。',
    '2026-04-08'
  ),
  (
    'マージ競合一括解消 (CLAUDE.md / settings.local.json / ROADMAP)',
    'CLAUDE.md・settings.local.json・GROWTH_STRATEGY_ROADMAP.mdの3ファイルでUpdateとStashの競合を解消。DesignTooling・MCP設定行・2026-04-08版最優先事項を正しく統合。',
    '2026-04-08'
  )
ON CONFLICT DO NOTHING;
