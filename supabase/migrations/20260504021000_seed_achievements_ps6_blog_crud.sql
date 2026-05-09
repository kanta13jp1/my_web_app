-- PS#6: Blog管理ページ完全CRUD + コメント返信 + 検索フィルター
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6: Blog管理ページ完全CRUD実装 — 新規作成/編集/削除/コメント返信/検索フィルター',
  'PS#5 S125のblog_management_page基盤(publish/toggle)に追加実装。①新規下書き作成: FABボタン+ダイアログ(タイトル/タグ/投稿先選択/本文Markdown)→blog.insert_post。②下書き編集: 鉛筆アイコン→ダイアログ(title/tags/content)→blog.update_post。③下書き削除: ゴミ箱アイコン+確認ダイアログ→blog.delete_post。④Qiitaコメント返信: 未返信コメントに「返信する」ボタン→blog.qiita_comment_post。⑤下書き検索・フィルター: _draftSearch(タイトル部分一致)/_draftStatusFilter(all/draft/ready)。⑥エラーハンドリング強化: _loadError状態+再試行SnackBar。⑦コントローラーのdispose追加。blog投稿フロー全自動化: GHA blog-draft(毎日3本生成)→管理UI(確認/編集/手動投稿)→blog-publish(ready自動投稿)。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
