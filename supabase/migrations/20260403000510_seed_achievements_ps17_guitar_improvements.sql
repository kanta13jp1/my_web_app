-- Session PS#17: ギター録音スタジオ完成度向上
-- 権限エラー改善・共有リンク機能・専用テーブル追加

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'ギター録音スタジオ完成度向上 — 権限エラー改善・共有リンク・専用テーブル (PS#17)',
    'PowerShell（全体管理）自己レビューPR#3の修正。(1) マイク権限エラーをNotAllowedError/NotFoundError/NotSupportedErrorの3種類に分類して日本語の具体的な解決手順（iOS/Android/Chrome/Firefox別）を表示するよう改善。生のJavaScript例外メッセージを除去。(2) 録音保存成功後、is_publicがtrueの場合に「共有リンクをコピー」ボタンを表示。URLはhttps://my-web-app-b67f4.web.app/#/guitar-recording-studio?share=<id>形式。クリップボードにコピーしてSnackBarで通知。(3) guitar_recordings専用テーブルをマイグレーション追加 — app_analytics JSONB依存から移行。user_id FK・RLS・is_public公開ポリシー・updated_atトリガー付き。flutter analyze 0エラー確認済み。',
    '2026-04-03'
  )
ON CONFLICT DO NOTHING;
