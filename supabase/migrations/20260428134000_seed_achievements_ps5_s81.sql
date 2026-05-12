-- PS#5 S81: ci.yml flutter test hard-fail gate (PR #860 統合) + PR #860 close
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ci.yml flutter test hard-fail + PR #860 close (PS#5 S81)',
  'ci.yml: flutter test を VM tests (browser除外) と web import smoke tests (chrome) に分離、両方 continue-on-error: false (hard fail) 化。PR #860 (codex/ci-web-test-hard-fail) の dart file 変更は PS#5 S74-S80 で main 直接反映済みのため、ci.yml 変更のみ cherry-pick して PR close。244eb523c on main。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
