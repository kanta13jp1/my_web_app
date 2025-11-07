# CORS Configuration Fix for Supabase

## Problem
```
Access-Control-Allow-Origin header is missing from Supabase REST API responses
Error: CORS policy blocking requests from https://my-web-app-b67f4.web.app
```

## Solution

### Step 1: Configure Allowed Origins in Supabase Dashboard

1. **Login to Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Navigate to your project: `smmkxxavexumewbfaqpy`

2. **Navigate to API Settings**
   - Click on "Settings" in the left sidebar
   - Select "API" from the settings menu

3. **Add Allowed Origins**
   - Look for "CORS Origins" or "Allowed Origins" section
   - Add the following origins:
     ```
     https://my-web-app-b67f4.web.app
     https://my-web-app-b67f4.firebaseapp.com
     ```
   - If you have a custom domain, add that too
   - For local development, optionally add:
     ```
     http://localhost:3000
     http://127.0.0.1:3000
     ```

4. **Save Settings**
   - Click "Save" or "Update" button
   - Wait 1-2 minutes for changes to propagate

### Step 2: Verify CORS Headers

After updating, you can verify the CORS headers using curl:

```bash
curl -I -X OPTIONS \
  -H "Origin: https://my-web-app-b67f4.web.app" \
  -H "Access-Control-Request-Method: GET" \
  "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1/guest_presence"
```

You should see:
```
Access-Control-Allow-Origin: https://my-web-app-b67f4.web.app
```

### Alternative: Use Supabase CLI (if available)

If CORS settings are configurable via CLI in future versions:

```bash
# Update config.toml (currently not supported for CORS)
# This is for reference only - use Dashboard instead
[api.cors]
allowed_origins = [
  "https://my-web-app-b67f4.web.app",
  "https://my-web-app-b67f4.firebaseapp.com"
]
```

## Additional Notes

- **Edge Functions**: Already have CORS configured (`*` wildcard)
- **REST API**: Requires explicit origin configuration in Dashboard
- **RLS Policies**: Already allow anonymous access to `guest_presence` table
- **502 Errors**: Should resolve once CORS is properly configured

## Testing After Fix

1. Clear browser cache
2. Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
3. Check browser console for CORS errors
4. Verify presence tracking works for both guests and authenticated users

## Related Files
- `/lib/services/presence_service.dart` - Presence tracking implementation
- `/supabase/migrations/20251106_growth_features.sql` - Database schema
- `/supabase/migrations/20251106_fix_site_statistics_rls.sql` - RLS fixes
