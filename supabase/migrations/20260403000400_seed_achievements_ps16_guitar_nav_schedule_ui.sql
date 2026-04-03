-- Session PS#16: ギター録音スタジオ導線強化 + ScheduleTaskMonitorCard UI改善
-- ホーム画面・ランディングページ最上部にギター録音バナーを追加
-- ScheduleTaskMonitorCard: エラー詳細展開・連続失敗カウント・管理リンク追加

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'ギター録音スタジオ導線強化 + Schedule監視UI改善 (PS#16)',
    'PowerShell（全体管理）自己レビューによる改善。(1) home_page.dart 最上部に_GuitarMainFeatureBannerウィジェットを新設 — ページ最初に目に入る位置でギター録音スタジオへ誘導（MAIN バッジ付き）。(2) landing_page.dart ヒーローセクション冒頭（アプリ名バッジより前）にギター録音バナーを移動 — 旧末尾の重複バナーを削除。(3) ScheduleTaskMonitorCard を全面改修: タスク行をタップで詳細展開、error_message と summary を全文表示、連続失敗3回以上でアラートバッジ表示、成功/失敗件数バッジをヘッダーに表示、管理ページリンク (claude.ai/code/scheduled) ボタン追加。flutter analyze 0エラー確認済み。',
    '2026-04-03'
  )
ON CONFLICT DO NOTHING;
