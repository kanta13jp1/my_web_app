-- PS#1 S13: comparison_page 27件重複 key 削除 + CI fix
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S13: comparison_page.dart 27件重複 map key 削除 (583→556 keys)',
  'PS#4 S171-S239 競合追加で smarthr/vercel/freee-hr/sentry 等 27種が重複。'
  'Python script で 2 回目出現 (各34行, 合計918行) を一括削除 → 556 keys 重複ゼロ。'
  'CI equal_keys_in_map fix → push (31ee4bda7)。'
  'PS#4 向け cross-instance-pr: 追加前既存 key チェック必須化を依頼。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
