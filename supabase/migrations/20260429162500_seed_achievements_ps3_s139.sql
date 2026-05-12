-- PS#3 S139: AI大学 372→374社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S139: Voyager 追加 — 372→373社',
    'Voyager (NVIDIA Research / Minecraft生涯学習エージェント / 3コンポーネント: Automatic Curriculum+Skill Library+Iterative Prompting / スキル獲得型学習 / JavaScript コード永続化 / ダイヤ採掘到達 / 生涯学習AI研究の最高峰 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S139: Generative Agents 追加 — 373→374社',
    'Generative Agents (Stanford University / Joon Sung Park et al. / 25エージェント仮想社会Smallville / 人間らしい行動シミュレーション / Memory Stream+Reflection+Planning / バレンタインパーティー自発計画 / CHI 2023 Best Paper / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
