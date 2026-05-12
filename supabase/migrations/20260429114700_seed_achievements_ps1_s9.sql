-- PS#1 S9: CI equal_keys_in_map fix + timestamp collision 2件修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S9: CI equal_keys_in_map fix + collision 2件修正',
  'CI flutter analyze 失敗: comparison_page.dart にintercom/zendesk/freshdesk/coda重複 map key。'
  'PS#4 S159-S170競合拡張時に既存 key再追加。Python script で4エントリ(各34行)削除 → 394 keys。'
  'migration collision: 110000(ps4_s171→110100) + 114500(ps4_s174→114600)。'
  'push: 2c32abbf0。CI + deploy-prod 復旧期待。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
