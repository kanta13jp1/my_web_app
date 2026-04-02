-- daily-development 2026-03-31: notification center UI + dart:html migration
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'アプリ内通知センター実装 (NotificationsPage)',
    'notification-center Edge FunctionとのFlutter連携UIを新規作成。未読/既読/すべてフィルター・7カテゴリ対応通知カードUI (アイコン・カラー・相対時刻表示)・既読マーク・全既読ボタン・RefreshIndicatorを実装。ホームAppBarに未読カウントバッジ付きベルアイコンを追加。business menuカタログにも通知センターエントリを追加。/notificationsルートをmain.dartに追加。flutter analyze 0件維持。',
    '2026-03-31'
  ),
  (
    'election_victory_page.dart dart:html廃止対応',
    'dart:htmlのBlob/AnchorElement/URL APIをdart:js_interop + package:web/web.dartに移行。Uint8List.fromList()でList<int>→Uint8List変換してtoJS適用。avoid_dynamic_calls (monthlyKpiのMap cast)・unused_local_variable (anchor変数削除) も同時修正。flutter analyze 0件維持。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
