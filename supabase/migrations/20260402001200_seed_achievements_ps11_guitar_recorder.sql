-- Session PS#11: ギターレコーディングスタジオ (メイン機能)
-- GuitarRecordingStudioPage: MediaRecorder API + メトロノーム + コード辞典 + 録音履歴

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'ギターレコーディングスタジオ — メイン機能 (PS#11)',
    'package:web + dart:js_interop を使用したブラウザネイティブ録音機能。MediaRecorder API で音声録音・一時停止・停止・再生・保存。メトロノーム (Web Audio API ビープ音, 30-300BPM, 拍子切替), コード辞典 (guitar-recording-studio Edge Function から15コード取得・ダイアグラム表示), 録音履歴タブ, ジャンルプリセット8種, チューニング選択, ランディングページへの導線バナー追加。flutter analyze 0エラー維持。',
    '2026-04-02'
  )
ON CONFLICT DO NOTHING;
