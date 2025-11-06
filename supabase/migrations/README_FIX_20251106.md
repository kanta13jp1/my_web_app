# Fix for Supabase API Errors (403 & 406)

## Date
2025-11-06

## Issues Fixed

### 1. **403 Forbidden Error** on `update_site_statistics` RPC
**Error:** `POST https://...supabase.co/rest/v1/rpc/update_site_statistics 403 (Forbidden)`

**Root Cause:**
- The `update_site_statistics()` function was running with the caller's permissions
- RLS policies on `site_statistics` table blocked all modifications by non-service-role users
- The function tried to INSERT/UPDATE records but was denied by RLS

**Fix:**
- Made the function `SECURITY DEFINER` so it runs with elevated privileges
- Added `SET search_path = public` for security best practices
- Granted EXECUTE permissions to `authenticated` and `anon` roles

### 2. **406 Not Acceptable Error** on `site_statistics` GET
**Error:** `GET https://...supabase.co/rest/v1/site_statistics?select=%2A&order=stat_date.desc.nullslast&limit=1 406 (Not Acceptable)`

**Root Cause:**
- The RLS policy `"Only service role can modify site statistics"` was created with `FOR ALL` command type
- This overly broad policy interfered with SELECT queries, causing content negotiation failures
- The `FOR ALL` policy applied to SELECT operations even though there was a separate SELECT policy

**Fix:**
- Removed the problematic `FOR ALL` policy
- Created specific policies for INSERT, UPDATE, and DELETE operations
- This allows the existing SELECT policy to work properly without interference

## Migration File
`supabase/migrations/20251106_fix_site_statistics_rls.sql`

## How to Apply the Migration

### Option 1: Using Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Open the file `supabase/migrations/20251106_fix_site_statistics_rls.sql`
4. Copy the entire contents
5. Paste into the SQL Editor
6. Click **Run** to execute the migration

### Option 2: Using Supabase CLI (if installed)
```bash
cd /home/user/my_web_app
supabase db push
```

### Option 3: Manual Application via psql
```bash
psql "postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres" \
  -f supabase/migrations/20251106_fix_site_statistics_rls.sql
```

## Verification

After applying the migration, verify the fixes work:

### Test 1: Check RLS Policies
```sql
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'site_statistics'
ORDER BY policyname;
```

Expected output:
- ✓ Policy for SELECT (viewable by everyone)
- ✓ Policy for INSERT (service role only)
- ✓ Policy for UPDATE (service role only)
- ✓ Policy for DELETE (service role only)
- ✗ NO policy with cmd='ALL'

### Test 2: Check Function Permissions
```sql
SELECT routine_name, security_type
FROM information_schema.routines
WHERE routine_name IN ('update_site_statistics', 'cleanup_old_presence')
AND routine_schema = 'public';
```

Expected output shows `security_type = 'DEFINER'` for both functions.

### Test 3: Test the API Calls
From your Flutter app, try:
1. Loading the Statistics page - should work without 406 error
2. The page will automatically call `update_site_statistics()` - should work without 403 error

## Technical Details

### What is SECURITY DEFINER?
- Functions marked with `SECURITY DEFINER` run with the privileges of the user who created them (usually the database owner)
- This is similar to `setuid` in Unix systems
- Essential for allowing regular users to perform privileged operations through controlled functions
- The `SET search_path = public` is added for security to prevent schema-related attacks

### Why Remove the FOR ALL Policy?
In PostgreSQL RLS:
- Multiple policies on the same table are combined with OR logic (for permissive policies)
- A `FOR ALL` policy applies to ALL command types (SELECT, INSERT, UPDATE, DELETE)
- Having both a `FOR SELECT` policy and a `FOR ALL` policy can cause conflicts
- Best practice: Use specific command types (SELECT, INSERT, UPDATE, DELETE) for clarity

## Files Changed
- `supabase/migrations/20251106_fix_site_statistics_rls.sql` (NEW)
- `supabase/migrations/README_FIX_20251106.md` (NEW - this file)

## Related Files
- `lib/services/presence_service.dart` (calls the RPC functions)
- `lib/pages/statistics_page.dart` (loads site statistics)
- `supabase/migrations/20251106_growth_features.sql` (original migration with the issues)

## Testing Checklist
- [ ] Apply the migration to your Supabase database
- [ ] Verify RLS policies using Test 1 above
- [ ] Verify function security using Test 2 above
- [ ] Open the Statistics page in your Flutter app
- [ ] Confirm no 403 or 406 errors in browser console
- [ ] Verify statistics are loading correctly
- [ ] Check that online user counts are updating

## Notes
- This migration is safe to run multiple times (idempotent)
- The `DROP POLICY IF EXISTS` ensures it won't fail if the policy was already removed
- The `CREATE OR REPLACE FUNCTION` ensures it updates the existing function
- All GRANT statements are safe to run multiple times
