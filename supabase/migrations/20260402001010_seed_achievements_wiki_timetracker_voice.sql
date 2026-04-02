-- Session: daily-development 2026-04-02 Wiki/TimeTracker/VoiceMemo
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Wiki・データベースページ実装',
    'wiki-database Edge FunctionのFlutter UI。階層型Wikiページ一覧・サブページ作成・テーブルデータ閲覧・ページ詳細表示をTabBarView 2タブ構成で実装。Notion/Confluence競合の中核機能。/wiki-database ルート追加。home_tool_catalog knowledge セクションに追加。',
    '2026-04-02'
  ),
  (
    '勤怠・時間追跡ページ実装',
    'time-tracker Edge FunctionのFlutter UI。出退勤打刻（出勤/退勤ボタン）・プロジェクト別作業時間記録・今日/今週/今月 SegmentedButton切り替え・プロジェクト別LinearProgressIndicatorバーグラフ・残業アラートバナーをTabBarView 3タブで実装。ジョブカン/Toggl/Clockify競合。/time-tracker ルート追加。',
    '2026-04-02'
  ),
  (
    '音声メモ・文字起こしページ実装',
    'voice-memo-transcriber Edge FunctionのFlutter UI。音声メモ追加（タイトル/文字起こし/AI要約）・ExpansionTileで詳細展開・検索機能（?view=search&q=）・ノートへの変換機能をリスト形式で実装。Google Keep/LINE/Discord競合。/voice-memo ルート追加。home_tool_catalog knowledge セクションに追加。',
    '2026-04-02'
  ),
  (
    '/ai-writing-assistant ルート修正',
    'home_tool_catalog.dartにAiWritingAssistantPageが追加済みだったがmain.dartにルートが未定義だった問題を修正。/ai-writing-assistant ルートとimportを追加。flutter analyze 0件維持。',
    '2026-04-02'
  ),
  (
    'viral_video_generator_page.dart lint修正',
    'require_trailing_commas エラー10件とDropdownButtonFormField.value deprecated警告を修正。initialValueに移行。flutter analyze 0件維持。',
    '2026-04-02'
  )
ON CONFLICT DO NOTHING;
