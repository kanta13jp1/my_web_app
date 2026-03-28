-- Session 2026-03-28: テンプレート広場拡充・ノートバージョン履歴・session-summaries修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'テンプレート広場 18種類実装',
    '日次記録・ビジネス・思考アイデア・学習成長・個人生活・技術開発の6カテゴリ・18テンプレートを整備。カテゴリフィルターUI付きで /templates ルートから直接アクセス可能に。',
    '2026-03-28'
  ),
  (
    'ノートバージョン履歴',
    'note_versions テーブル新設。手動保存のたびにスナップショットを記録し、AppBarの履歴ボタンからBottomSheetで最新30件を閲覧・復元できる機能を追加。Notionパリティの短期ギャップを解消。',
    '2026-03-28'
  ),
  (
    'pubspec.yaml 警告修正',
    'docs/session-summaries/ ディレクトリが存在しないことでfutter analyzeに警告が出ていた問題を修正。flutter analyze 0件を維持。',
    '2026-03-28'
  )
ON CONFLICT DO NOTHING;
