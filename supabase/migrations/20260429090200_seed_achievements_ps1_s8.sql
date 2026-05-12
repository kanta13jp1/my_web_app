-- PS#1 S8: migration timestamp collision 追加3件修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S8: migration timestamp collision 追加3件修正 (075000/080000/090000)',
  'deploy-prod 失敗 (run 25091716827) で3つのtimestamp collision検知。'
  '075000: ps4_s150+ps5_s101 → ps5_s101を075100にリネーム。'
  '080000: ps5_s104+ps6_s117 → ps6_s117を080100にリネーム。'
  '090000: ps4_s160+ps5_s105 → ps5_s105を090100にリネーム。'
  '3件一括 git mv → 648bd919b push完了。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
