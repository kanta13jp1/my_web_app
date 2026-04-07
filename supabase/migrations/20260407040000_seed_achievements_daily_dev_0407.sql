-- daily-development 2026-04-07: 地方選挙±1年スケジュール・統一地方選カウントダウン・ギタースタジオX自動投稿完成
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '地方選挙スケジュール±1年表示',
    'local-election-intelligence Edge FunctionのSCHEDULE_WINDOW_DAYSを120→365に拡大。isPastフィールド追加で過去/未来を分割表示。過去エントリはグレー「結果」バッジ付きで折りたたみ表示。',
    '2026-04-07'
  ),
  (
    '統一地方選挙2027カウントダウン',
    'election_victory_pageに_buildUnifiedElectionCountdown()を追加。第一次・第二次の公示日と投開票日の残日数を4セルのカードで表示。',
    '2026-04-07'
  ),
  (
    'ギタースタジオX自動投稿UI完成',
    '公開録音保存成功後にX (@kanta13jp1) 自動投稿確認バナーを表示。「ギャラリー →」ボタンで/public-guitar-galleryへの導線も追加。バイラル機能のUI/バックエンド連携が完成。',
    '2026-04-07'
  )
ON CONFLICT DO NOTHING;
