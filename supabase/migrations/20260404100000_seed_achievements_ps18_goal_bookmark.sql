-- Session 18: 目標管理・ブックマーク同期ページ実装 + ギタースタジオ修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '目標管理ページ実装 (Notion/Liven競合)',
    'goal-tracker Edge Function と連携する目標管理UIを実装。短期/中期/長期目標・マイルストーン管理・進捗追跡・達成記録機能を搭載。Flutter 3.33対応のasync/await安全パターン適用。',
    '2026-04-04'
  ),
  (
    'ブックマーク同期ページ実装 (Pocket/Instapaper競合)',
    'bookmark-sync Edge Function と連携するURL保存UIを実装。タグ管理・既読管理・統計表示・フィルタリング機能搭載。bookmarksテーブルのDBマイグレーションも追加。',
    '2026-04-04'
  ),
  (
    'ギタースタジオページ品質修正',
    'dart:mathのtanh未定義エラーをexp数式で解決。削除済みフィールド参照エラーを修正。share_plus/upload機能を正常化。flutter analyze 0エラー維持。',
    '2026-04-04'
  ),
  (
    'bookmark-sync Edge Functionバグ修正',
    'Deno関数内でconst bodyが同スコープで2回宣言されていたバグを修正。POST bodyのストリーム二重消費問題を解消。',
    '2026-04-04'
  )
ON CONFLICT DO NOTHING;
