# Fix for 406 Error on user_stats Endpoint

## Problem

The application is receiving a **406 (Not Acceptable)** error when trying to access the `user_stats` table:

```
smmkxxavexumewbfaqpy.supabase.co/rest/v1/user_stats?select=total_points&user_id=eq.927f8dd2-3918-4bca-82ea-1619cb4810ef
```

## Root Cause

The Row Level Security (RLS) policy on the `user_stats` table is too restrictive. The current policy only allows users to view **their own** stats:

```sql
CREATE POLICY "Users can view their own stats"
  ON user_stats FOR SELECT
  USING (auth.uid() = user_id);
```

However, the leaderboard functionality (`lib/services/gamification_service.dart` lines 509-553) needs to read **all users'** stats to display rankings. This mismatch causes the 406 error.

## Solution

Update the RLS policy to allow public read access to `user_stats` while maintaining security for write operations.

### Steps to Fix

1. **Open Supabase Dashboard**
   - Go to https://app.supabase.com
   - Select your project: `smmkxxavexumewbfaqpy`

2. **Navigate to SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New query"

3. **Run the Migration**
   - Copy and paste the following SQL:

```sql
-- Fix user_stats RLS policies to allow leaderboard access
-- This allows anyone to read user stats for leaderboard functionality
-- while maintaining write security

-- First, drop the existing restrictive SELECT policy
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;

-- Create a new public read policy for leaderboard access
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);

-- Verify the policies are correct
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'user_stats';
```

4. **Click "Run"** to execute the migration

5. **Verify the Fix**
   - Refresh your application
   - The 406 error should be resolved
   - The leaderboard should now display all users

## Security Considerations

This change allows anyone (authenticated or anonymous) to read user stats, which is appropriate for a leaderboard feature. The following policies ensure data security:

- **INSERT**: Only authenticated users can insert their own stats
- **UPDATE**: Only authenticated users can update their own stats
- **DELETE**: Handled automatically via CASCADE on user deletion

User stats are intentionally public for competitive/social features like leaderboards.

## Migration File

The migration has been saved to:
```
supabase/migrations/20251109120000_fix_user_stats_leaderboard_rls.sql
```

This file is now part of your migration history for future deployments.
