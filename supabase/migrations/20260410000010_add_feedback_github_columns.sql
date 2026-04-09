-- app_feedback: GitHub Issue連携・メール通知用カラム追加
-- submit-feedback Edge Function が github_issue_number/url を書き込む
-- notify-feedback-implemented が user_email を利用してリリース通知を送る

ALTER TABLE app_feedback
  ADD COLUMN IF NOT EXISTS github_issue_number int,
  ADD COLUMN IF NOT EXISTS github_issue_url    text,
  ADD COLUMN IF NOT EXISTS user_email          text;

CREATE INDEX IF NOT EXISTS idx_app_feedback_github_issue
  ON app_feedback(github_issue_number)
  WHERE github_issue_number IS NOT NULL;
