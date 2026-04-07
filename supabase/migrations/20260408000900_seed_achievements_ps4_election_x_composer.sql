-- Session PowerShell#4: 地方選挙 X スレッド投稿コンポーザー追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '地方選挙 X スレッド投稿コンポーザー',
  '選挙ページに「週末選挙投稿」ボタンを追加。候補者未擁立の選挙を都道府県別にまとめたXスレッド（2ツイート形式）を生成・プレビュー・編集・投稿できるコンポーザーダイアログを実装。ユーザーが指定したフォーマット（イントロ文+選挙リスト/統計+公開ノートURL）に対応。',
  '2026-04-08'
)
ON CONFLICT DO NOTHING;
