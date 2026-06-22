-- feature_releases に release-notes.json 自動同期用の source_id を追加 (Issue #3279 残課題)
-- source_id = release-notes.json の change id (例: pr-3276)。upsert の重複防止キー。
ALTER TABLE feature_releases ADD COLUMN IF NOT EXISTS source_id text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'feature_releases_source_id_key'
  ) THEN
    ALTER TABLE feature_releases
      ADD CONSTRAINT feature_releases_source_id_key UNIQUE (source_id);
  END IF;
END $$;
