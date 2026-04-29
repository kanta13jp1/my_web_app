-- PS#1 S11: migration collision 構造的防止 cross-instance-pr
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S11: migration collision 構造的防止 cross-instance-pr (全インスタンス向け)',
  '1セッション中に7件 collision (S7-S10) → deploy-prod 連続 FAIL の根本原因分析。'
  '原因: YYYYMMDDHHMMSS ベースで複数インスタンスが同秒実行 → 同一タイムスタンプ衝突。'
  'cross-instance-pr: 3方式提案 (MAX+1 increment / instance offset / push前 check)。'
  'WF 最終: Collision Check 4/4 success / CI success / deploy-prod healthy (a342a185e)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
