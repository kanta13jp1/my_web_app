-- Migration to fix referral_codes table column name
-- This handles cases where the column might be named 'code' instead of 'referral_code'

-- Check if 'code' column exists and 'referral_code' doesn't, then rename
DO $$
BEGIN
    -- Check if 'code' column exists and 'referral_code' doesn't
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'referral_codes'
        AND column_name = 'code'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'referral_codes'
        AND column_name = 'referral_code'
    ) THEN
        -- Rename the column
        ALTER TABLE referral_codes RENAME COLUMN code TO referral_code;
        RAISE NOTICE 'Renamed column code to referral_code in referral_codes table';
    ELSIF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'referral_codes'
        AND column_name = 'referral_code'
    ) THEN
        RAISE NOTICE 'Column referral_code already exists in referral_codes table';
    ELSE
        RAISE NOTICE 'Neither code nor referral_code column found in referral_codes table';
    END IF;
END $$;

-- Update index name if it was created with old column name
DO $$
BEGIN
    -- Drop old index if it exists
    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE indexname = 'idx_referral_codes_code'
        AND tablename = 'referral_codes'
    ) THEN
        DROP INDEX IF EXISTS idx_referral_codes_code;
        -- Recreate with correct column name
        CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(referral_code);
        RAISE NOTICE 'Recreated index idx_referral_codes_code with correct column name';
    END IF;
END $$;
