-- Session 2026-03-31: LPにLiveGrowthBanner追加・ホームにProfileProgressCard追加・選挙ページGemini分析UI
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'LPにLiveGrowthBannerを追加 (登録者数リアルタイム表示)',
    'ランディングページのソーシャルプルーフ欄の直下にLiveGrowthBannerを設置。登録者数・現在のLP閲覧者数・今日の登録数・競合Notion/Evernoteとの差分をリアルタイム更新 (20秒間隔) で表示。コンバージョン率向上を狙う。',
    '2026-03-31'
  ),
  (
    'ホーム画面にProfileProgressCardを追加 (プロフィール完成度)',
    'home_page.dartにProfileProgressCardを追加。LinkedIn型のプロフィール完成度バーで未設定項目を明示し、プロフィール設定への誘導を強化。完成度100%でミニバッジ表示に変化。',
    '2026-03-31'
  ),
  (
    'ユーザーマニュアルQUICK ACCESSナビゲーション全修正',
    'user_manual_page.dartのセクション2・4の全ナビゲーション手順を現行UIに合わせて修正。CFO/CHO/CHRO OFFICE→OFFICE KPI SNAPSHOT、CMO/CKO OFFICE→QUICK ACCESS知識・意思決定、CSO OFFICE→QUICK ACCESS生活・整理、GROWTH/成長導線→QUICK ACCESS成長・発信に更新。',
    '2026-03-31'
  ),
  (
    '選挙ページにGemini AI分析ボタンを追加 (gemini-election-analysis連携)',
    'ElectionVictoryPageのAppBarにGemini AI分析ボタン(Icons.auto_awesome)を追加。タップでgemini-election-analysis Edge Functionを呼び出し、取得議員数と700人残り人数をAI整理メモセクションに表示。EdgeFunctionSummaryCardにも登録 (41関数体制)。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
