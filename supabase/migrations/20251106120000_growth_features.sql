-- Growth Features Migration
-- Created: 2025-11-06
-- Purpose: Add features to increase user registration and engagement

-- ============================================================
-- 1. SITE STATISTICS TABLE
-- ============================================================
-- Tracks overall site statistics including total users, active users, etc.
CREATE TABLE IF NOT EXISTS site_statistics (
    id BIGSERIAL PRIMARY KEY,
    stat_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_users INTEGER DEFAULT 0,
    new_users_today INTEGER DEFAULT 0,
    active_users_today INTEGER DEFAULT 0,
    total_notes_created INTEGER DEFAULT 0,
    total_shares INTEGER DEFAULT 0,
    total_achievements_unlocked INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(stat_date)
);

-- Index for fast date lookups
CREATE INDEX IF NOT EXISTS idx_site_statistics_date ON site_statistics(stat_date DESC);

-- ============================================================
-- 2. USER PRESENCE TABLE
-- ============================================================
-- Tracks online/offline status of users in real-time
CREATE TABLE IF NOT EXISTS user_presence (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    is_online BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    page_path TEXT,
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, session_id)
);

-- Indexes for presence tracking
CREATE INDEX IF NOT EXISTS idx_user_presence_user_id ON user_presence(user_id);
CREATE INDEX IF NOT EXISTS idx_user_presence_online ON user_presence(is_online, last_seen);
CREATE INDEX IF NOT EXISTS idx_user_presence_last_seen ON user_presence(last_seen DESC);

-- ============================================================
-- 3. GUEST PRESENCE TABLE
-- ============================================================
-- Tracks guest (non-authenticated) visitors
CREATE TABLE IF NOT EXISTS guest_presence (
    id BIGSERIAL PRIMARY KEY,
    session_id TEXT NOT NULL,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    page_path TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(session_id)
);

CREATE INDEX IF NOT EXISTS idx_guest_presence_last_seen ON guest_presence(last_seen DESC);

-- ============================================================
-- 4. REFERRAL CODES TABLE
-- ============================================================
-- Manages user referral codes and tracking
CREATE TABLE IF NOT EXISTS referral_codes (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    referral_code TEXT NOT NULL UNIQUE,
    total_referrals INTEGER DEFAULT 0,
    successful_referrals INTEGER DEFAULT 0,
    bonus_points_earned INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(referral_code);
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(user_id);

-- ============================================================
-- 5. REFERRALS TABLE
-- ============================================================
-- Tracks individual referral relationships
CREATE TABLE IF NOT EXISTS referrals (
    id BIGSERIAL PRIMARY KEY,
    referrer_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    referral_code TEXT NOT NULL,
    bonus_points INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending', -- pending, completed, expired
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(referred_user_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON referrals(status);

-- ============================================================
-- 6. DAILY CHALLENGES TABLE
-- ============================================================
-- Defines daily challenges for user engagement
CREATE TABLE IF NOT EXISTS daily_challenges (
    id BIGSERIAL PRIMARY KEY,
    challenge_date DATE NOT NULL,
    challenge_type TEXT NOT NULL, -- create_notes, earn_points, share_notes, etc.
    challenge_title TEXT NOT NULL,
    challenge_description TEXT NOT NULL,
    target_value INTEGER NOT NULL,
    reward_points INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(challenge_date, challenge_type)
);

CREATE INDEX IF NOT EXISTS idx_daily_challenges_date ON daily_challenges(challenge_date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_challenges_active ON daily_challenges(is_active, challenge_date);

-- ============================================================
-- 7. USER DAILY CHALLENGE PROGRESS TABLE
-- ============================================================
-- Tracks user progress on daily challenges
CREATE TABLE IF NOT EXISTS user_challenge_progress (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    challenge_id BIGINT REFERENCES daily_challenges(id) ON DELETE CASCADE,
    current_progress INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    reward_claimed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, challenge_id)
);

CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_user ON user_challenge_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_challenge ON user_challenge_progress(challenge_id);
CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_completed ON user_challenge_progress(is_completed);

-- ============================================================
-- 8. DAILY LOGIN REWARDS TABLE
-- ============================================================
-- Tracks daily login bonuses
CREATE TABLE IF NOT EXISTS daily_login_rewards (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    login_date DATE NOT NULL,
    consecutive_days INTEGER DEFAULT 1,
    bonus_points INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, login_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_login_user ON daily_login_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_login_date ON daily_login_rewards(login_date DESC);

-- ============================================================
-- 9. PUBLIC MEMOS TABLE
-- ============================================================
-- Extends notes to support public sharing and discovery
CREATE TABLE IF NOT EXISTS public_memos (
    id BIGSERIAL PRIMARY KEY,
    note_id BIGINT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT,
    category TEXT,
    like_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT TRUE,
    published_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(note_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_public_memos_user ON public_memos(user_id);
CREATE INDEX IF NOT EXISTS idx_public_memos_public ON public_memos(is_public, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_public_memos_likes ON public_memos(like_count DESC);
CREATE INDEX IF NOT EXISTS idx_public_memos_views ON public_memos(view_count DESC);

-- ============================================================
-- 10. MEMO LIKES TABLE
-- ============================================================
-- Tracks user likes on public memos
CREATE TABLE IF NOT EXISTS memo_likes (
    id BIGSERIAL PRIMARY KEY,
    memo_id BIGINT REFERENCES public_memos(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(memo_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_memo_likes_memo ON memo_likes(memo_id);
CREATE INDEX IF NOT EXISTS idx_memo_likes_user ON memo_likes(user_id);

-- ============================================================
-- 11. ONBOARDING STATUS TABLE
-- ============================================================
-- Tracks user onboarding progress
CREATE TABLE IF NOT EXISTS user_onboarding (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    welcome_bonus_claimed BOOLEAN DEFAULT FALSE,
    tutorial_completed BOOLEAN DEFAULT FALSE,
    first_note_created BOOLEAN DEFAULT FALSE,
    first_category_created BOOLEAN DEFAULT FALSE,
    profile_completed BOOLEAN DEFAULT FALSE,
    onboarding_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_onboarding_user ON user_onboarding(user_id);

-- ============================================================
-- TRIGGERS FOR AUTO-UPDATING updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
DROP TRIGGER IF EXISTS update_site_statistics_updated_at ON site_statistics;
DROP TRIGGER IF EXISTS update_user_presence_updated_at ON user_presence;
DROP TRIGGER IF EXISTS update_referral_codes_updated_at ON referral_codes;
DROP TRIGGER IF EXISTS update_daily_challenges_updated_at ON daily_challenges;
DROP TRIGGER IF EXISTS update_user_challenge_progress_updated_at ON user_challenge_progress;
DROP TRIGGER IF EXISTS update_public_memos_updated_at ON public_memos;
DROP TRIGGER IF EXISTS update_user_onboarding_updated_at ON user_onboarding;

CREATE TRIGGER update_site_statistics_updated_at BEFORE UPDATE ON site_statistics FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_presence_updated_at BEFORE UPDATE ON user_presence FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_referral_codes_updated_at BEFORE UPDATE ON referral_codes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_daily_challenges_updated_at BEFORE UPDATE ON daily_challenges FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_challenge_progress_updated_at BEFORE UPDATE ON user_challenge_progress FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_public_memos_updated_at BEFORE UPDATE ON public_memos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_onboarding_updated_at BEFORE UPDATE ON user_onboarding FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Site statistics: Read-only for all authenticated users
ALTER TABLE site_statistics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Site statistics are viewable by everyone" ON site_statistics;
DROP POLICY IF EXISTS "Only service role can modify site statistics" ON site_statistics;
CREATE POLICY "Site statistics are viewable by everyone" ON site_statistics FOR SELECT USING (true);
CREATE POLICY "Only service role can modify site statistics" ON site_statistics FOR ALL USING (false);

-- User presence: Users can manage their own presence
ALTER TABLE user_presence ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view all presence data" ON user_presence;
DROP POLICY IF EXISTS "Users can insert own presence" ON user_presence;
DROP POLICY IF EXISTS "Users can update own presence" ON user_presence;
DROP POLICY IF EXISTS "Users can delete own presence" ON user_presence;
CREATE POLICY "Users can view all presence data" ON user_presence FOR SELECT USING (true);
CREATE POLICY "Users can insert own presence" ON user_presence FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own presence" ON user_presence FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own presence" ON user_presence FOR DELETE USING (auth.uid() = user_id);

-- Guest presence: Publicly accessible
ALTER TABLE guest_presence ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Guest presence viewable by all" ON guest_presence;
DROP POLICY IF EXISTS "Anyone can insert guest presence" ON guest_presence;
DROP POLICY IF EXISTS "Anyone can update guest presence" ON guest_presence;
DROP POLICY IF EXISTS "Anyone can delete old guest presence" ON guest_presence;
CREATE POLICY "Guest presence viewable by all" ON guest_presence FOR SELECT USING (true);
CREATE POLICY "Anyone can insert guest presence" ON guest_presence FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update guest presence" ON guest_presence FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete old guest presence" ON guest_presence FOR DELETE USING (true);

-- Referral codes: Users can view all, manage their own
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Referral codes viewable by all authenticated" ON referral_codes;
DROP POLICY IF EXISTS "Users can insert own referral code" ON referral_codes;
DROP POLICY IF EXISTS "Users can update own referral code" ON referral_codes;
CREATE POLICY "Referral codes viewable by all authenticated" ON referral_codes FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can insert own referral code" ON referral_codes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own referral code" ON referral_codes FOR UPDATE USING (auth.uid() = user_id);

-- Referrals: Users can view their referrals
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their referrals" ON referrals;
DROP POLICY IF EXISTS "System can insert referrals" ON referrals;
DROP POLICY IF EXISTS "System can update referrals" ON referrals;
CREATE POLICY "Users can view their referrals" ON referrals FOR SELECT USING (auth.uid() = referrer_user_id OR auth.uid() = referred_user_id);
CREATE POLICY "System can insert referrals" ON referrals FOR INSERT WITH CHECK (true);
CREATE POLICY "System can update referrals" ON referrals FOR UPDATE USING (true);

-- Daily challenges: Readable by all authenticated users
ALTER TABLE daily_challenges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Challenges viewable by authenticated" ON daily_challenges;
CREATE POLICY "Challenges viewable by authenticated" ON daily_challenges FOR SELECT USING (auth.role() = 'authenticated');

-- User challenge progress: Users can view and update their own
ALTER TABLE user_challenge_progress ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own progress" ON user_challenge_progress;
DROP POLICY IF EXISTS "Users can insert own progress" ON user_challenge_progress;
DROP POLICY IF EXISTS "Users can update own progress" ON user_challenge_progress;
CREATE POLICY "Users can view own progress" ON user_challenge_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own progress" ON user_challenge_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own progress" ON user_challenge_progress FOR UPDATE USING (auth.uid() = user_id);

-- Daily login rewards: Users can view their own
ALTER TABLE daily_login_rewards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own login rewards" ON daily_login_rewards;
DROP POLICY IF EXISTS "Users can insert own login rewards" ON daily_login_rewards;
CREATE POLICY "Users can view own login rewards" ON daily_login_rewards FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own login rewards" ON daily_login_rewards FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Public memos: Viewable by all, manageable by owner
ALTER TABLE public_memos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public memos viewable by all" ON public_memos;
DROP POLICY IF EXISTS "Users can insert own public memos" ON public_memos;
DROP POLICY IF EXISTS "Users can update own public memos" ON public_memos;
DROP POLICY IF EXISTS "Users can delete own public memos" ON public_memos;
CREATE POLICY "Public memos viewable by all" ON public_memos FOR SELECT USING (is_public = true OR auth.uid() = user_id);
CREATE POLICY "Users can insert own public memos" ON public_memos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own public memos" ON public_memos FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own public memos" ON public_memos FOR DELETE USING (auth.uid() = user_id);

-- Memo likes: Users can like and view likes
ALTER TABLE memo_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Likes viewable by all" ON memo_likes;
DROP POLICY IF EXISTS "Authenticated users can like" ON memo_likes;
DROP POLICY IF EXISTS "Users can unlike own likes" ON memo_likes;
CREATE POLICY "Likes viewable by all" ON memo_likes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can like" ON memo_likes FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can unlike own likes" ON memo_likes FOR DELETE USING (auth.uid() = user_id);

-- User onboarding: Users can view and update their own
ALTER TABLE user_onboarding ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own onboarding" ON user_onboarding;
DROP POLICY IF EXISTS "Users can insert own onboarding" ON user_onboarding;
DROP POLICY IF EXISTS "Users can update own onboarding" ON user_onboarding;
CREATE POLICY "Users can view own onboarding" ON user_onboarding FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own onboarding" ON user_onboarding FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own onboarding" ON user_onboarding FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- FUNCTIONS FOR STATISTICS UPDATES
-- ============================================================

-- Function to update site statistics daily
CREATE OR REPLACE FUNCTION update_site_statistics()
RETURNS void AS $$
BEGIN
    INSERT INTO site_statistics (
        stat_date,
        total_users,
        new_users_today,
        active_users_today,
        total_notes_created,
        total_shares,
        total_achievements_unlocked
    )
    SELECT
        CURRENT_DATE,
        (SELECT COUNT(*) FROM auth.users),
        (SELECT COUNT(*) FROM auth.users WHERE DATE(created_at) = CURRENT_DATE),
        (SELECT COUNT(DISTINCT user_id) FROM user_presence WHERE DATE(last_seen) = CURRENT_DATE),
        (SELECT COALESCE(SUM(notes_created), 0) FROM user_stats),
        (SELECT COALESCE(SUM(notes_shared), 0) FROM user_stats),
        (SELECT COUNT(*) FROM user_achievements WHERE is_unlocked = true)
    ON CONFLICT (stat_date)
    DO UPDATE SET
        total_users = EXCLUDED.total_users,
        new_users_today = EXCLUDED.new_users_today,
        active_users_today = EXCLUDED.active_users_today,
        total_notes_created = EXCLUDED.total_notes_created,
        total_shares = EXCLUDED.total_shares,
        total_achievements_unlocked = EXCLUDED.total_achievements_unlocked,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old presence records (older than 30 minutes)
CREATE OR REPLACE FUNCTION cleanup_old_presence()
RETURNS void AS $$
BEGIN
    -- Mark users as offline if not seen in 5 minutes
    UPDATE user_presence
    SET is_online = false
    WHERE last_seen < NOW() - INTERVAL '5 minutes'
    AND is_online = true;

    -- Delete old offline records (older than 24 hours)
    DELETE FROM user_presence
    WHERE last_seen < NOW() - INTERVAL '24 hours'
    AND is_online = false;

    -- Delete old guest presence (older than 30 minutes)
    DELETE FROM guest_presence
    WHERE last_seen < NOW() - INTERVAL '30 minutes';
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Excluding similar looking characters
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to create referral code for new user
CREATE OR REPLACE FUNCTION create_user_referral_code()
RETURNS TRIGGER AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
BEGIN
    -- Generate unique referral code
    LOOP
        new_code := generate_referral_code();
        SELECT EXISTS(SELECT 1 FROM referral_codes WHERE referral_code = new_code) INTO code_exists;
        EXIT WHEN NOT code_exists;
    END LOOP;

    -- Insert referral code for new user
    INSERT INTO referral_codes (user_id, referral_code)
    VALUES (NEW.id, new_code);

    -- Initialize onboarding status
    INSERT INTO user_onboarding (user_id)
    VALUES (NEW.id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create referral code when user signs up
DROP TRIGGER IF EXISTS create_referral_code_on_signup ON auth.users;
CREATE TRIGGER create_referral_code_on_signup
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_referral_code();

-- ============================================================
-- SEED DATA: Initial Daily Challenges
-- ============================================================
-- Use DO block to handle conflicts gracefully
DO $$
BEGIN
    INSERT INTO daily_challenges (challenge_date, challenge_type, challenge_title, challenge_description, target_value, reward_points)
    VALUES
        (CURRENT_DATE, 'create_notes', '今日のメモ作成', '3つのメモを作成しよう', 3, 50),
        (CURRENT_DATE, 'earn_points', 'ポイント獲得', '100ポイントを獲得しよう', 100, 30),
        (CURRENT_DATE, 'share_notes', 'メモを共有', '1つのメモを共有しよう', 1, 40)
    ON CONFLICT (challenge_date, challenge_type) DO NOTHING;
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore errors if challenges already exist
        NULL;
END $$;

-- ============================================================
-- COMMENTS
-- ============================================================
COMMENT ON TABLE site_statistics IS 'Tracks daily site-wide statistics';
COMMENT ON TABLE user_presence IS 'Tracks real-time online/offline status of authenticated users';
COMMENT ON TABLE guest_presence IS 'Tracks real-time presence of guest visitors';
COMMENT ON TABLE referral_codes IS 'Stores unique referral codes for each user';
COMMENT ON TABLE referrals IS 'Tracks referral relationships between users';
COMMENT ON TABLE daily_challenges IS 'Defines daily challenges for user engagement';
COMMENT ON TABLE user_challenge_progress IS 'Tracks user progress on daily challenges';
COMMENT ON TABLE daily_login_rewards IS 'Records daily login bonuses';
COMMENT ON TABLE public_memos IS 'Stores publicly shared memos for discovery';
COMMENT ON TABLE memo_likes IS 'Tracks likes on public memos';
COMMENT ON TABLE user_onboarding IS 'Tracks onboarding progress for new users';
