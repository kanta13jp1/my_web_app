-- Issue #513: add ai_feedback_source to track whether feedback came from real audio or metadata-only
ALTER TABLE guitar_recordings
  ADD COLUMN IF NOT EXISTS ai_feedback_source text;
