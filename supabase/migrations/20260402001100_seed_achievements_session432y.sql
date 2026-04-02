-- Session 432y (Web版): ギター録音スタジオ (メイン機能) + 音楽コラボ + エフェクト
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('guitar-recording-studio Edge Function (メイン機能)', 'スマホでギター演奏を録音・管理するメイン機能 — Web Audio API対応、5チューニング(standard/drop_d/open_g/open_d/dadgad)、15コード辞典、8ジャンル録音プリセット(acoustic_fingerpicking/rock_rhythm/blues_lead/jazz_clean/metal_heavy/classical/funk_rhythm/ambient)、メトロノーム、マルチトラック重ね録り、練習記録・連続日数ストリーク、録音の公開・いいね', '2026-04-02'),
  ('music-collaboration Edge Function', '音楽コラボレーション機能 — 公開録音フィード(人気/トレンド/新着ソート)、コラボセッション(jam/remix/duet/band_practice/lesson)、招待コード生成、最大8人参加、トラック追加、X/LINE/Facebook共有、ジャンルフィルタ', '2026-04-02'),
  ('audio-effects-processor Edge Function', 'ギターエフェクトプロセッサー — 20種類のエフェクト(リバーブ6種/ディストーション3種/ディレイ2種/モジュレーション3種/フィルター1種/ダイナミクス4種/EQ1種)、8つのチェーンプリセット(clean_sparkle/blues_king/rock_classic/metal_wall/ambient_dream/funk_machine/jazz_warm/acoustic_natural)、カスタムチェーン保存、全パラメータ定義をWeb Audio APIノード名付きで提供', '2026-04-02')
ON CONFLICT DO NOTHING;
