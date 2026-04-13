---
title: "How a Bash Quoting Artifact Broke Our Production PostgreSQL Deploy"
tags: PostgreSQL,Supabase,bash,GitHubActions,buildinpublic
published: false
---

# How a Bash Quoting Artifact Broke Our Production PostgreSQL Deploy

## The Mystery Error

Our production Supabase migration deploy suddenly started failing with `SQLSTATE 42601`:

```
ERROR: syntax error at or near "'"" (SQLSTATE 42601)
At statement: 0
-- AI University content: Hailuo AI (MiniMax)
```

The SQL file looked perfectly fine in the editor. After investigation, the culprit turned out to be a **bash shell quoting artifact** (`'"'"'`) that had leaked directly into a SQL migration file.

## What is `'"'"'`?

In bash, you can't use a single quote `'` inside a single-quoted string. The workaround is to close the string, insert the character in double-quotes, then reopen:

```bash
# Three-part construction:
'...'   # single-quoted string
"'"     # single quote in double-quotes
'...'   # resume single-quoted string

# Commonly seen in curl -d:
curl -d '"'"'{"key":"value"}'"'"'
# Expands to: '{"key":"value"}'
```

This `'"'"'` pattern is a valid bash escaping technique — but it's meaningless (and dangerous) in SQL.

## What Went Wrong

We were inserting API documentation with curl examples directly into a SQL migration file:

```sql
-- Problematic SQL (shell quoting artifact leaked in)
INSERT INTO ai_university_content (...) VALUES
(
  'hailuo', 'api', 'API Guide',
  E'...curl examples...\n  -d '"'"'{\n    "model": "video-01"\n  }'"'"'\n...',
  ...
)
```

**The bash curl example was copy-pasted into SQL string content without being escaped.**

Here's what PostgreSQL sees when it hits `'"'"'`:

1. `'` → string start
2. `"` → literal `"` character
3. `'` → **string end** (parser thinks the string is closed here)
4. `"'` → **syntax error 42601**

## The Fix

### Option 1: SQL escape with `''` (what we used)

In PostgreSQL E-string notation (`E'...'`), escape single quotes by doubling them:

```sql
-- Fixed
E'...-d ''{\\n    "model": "video-01"\\n  }''\\n...'
```

Python batch fix across migration files:

```python
content = open('migration.sql', 'r', encoding='utf-8').read()
content = content.replace("'\"'\"'", "''")
open('migration.sql', 'w', encoding='utf-8').write(content)
```

### Option 2: Dollar-quoting (cleaner for long content)

```sql
-- No escaping needed inside $$...$$
$$
-d '{"model": "video-01"}'
$$
```

For long content with many single quotes, dollar-quoting is much more readable.

## Prevention

### 1. CI Gate — catch it before it reaches production

We added this step to our `ci.yml`:

```yaml
- name: Check SQL migration shell quoting artifacts
  run: |
    python3 -c "
    import os, sys
    found = []
    for f in os.listdir('supabase/migrations'):
        if f.endswith('.sql'):
            path = os.path.join('supabase/migrations', f)
            content = open(path, errors='replace').read()
            if \"'\\\"'\\\"'\" in content:
                found.append(path)
    if found:
        print('FOUND: ' + ', '.join(found))
        sys.exit(1)
    else:
        print(f'OK: {len(found)} issues in migrations')
    "
  continue-on-error: false
```

This blocks the deploy before the artifact reaches Supabase.

### 2. Use dollar-quoting for shell code samples

```sql
-- Safe: no quoting issues
INSERT INTO content (body) VALUES (
  $$
  curl -X POST https://api.example.com \
    -H "Content-Type: application/json" \
    -d '{"model": "video-01"}'
  $$
);
```

### 3. Also fixed: GitHub Actions workflow quoting

A related issue: `${{ steps.outputs.title }}` injected directly into a bash string breaks when the title contains `"`:

```yaml
# Dangerous — breaks if title has double-quotes
run: |
  TITLE="${{ steps.meta.outputs.title }}"

# Safe — pass through env: block
env:
  ARTICLE_TITLE: ${{ steps.meta.outputs.title }}
run: |
  TITLE="$ARTICLE_TITLE"
```

GitHub Actions substitutes `${{ }}` expressions *before* the shell runs — so any `"` in the value terminates the outer string.

## Summary

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| `SQLSTATE 42601` | bash `'"'"'` artifact in SQL string | Replace with `''` |
| GitHub Actions syntax error | `${{ expr }}` with `"` in value | Use `env:` block |
| Recurring deploy failures | No pre-deploy SQL lint | Added CI check |

**Key takeaway**: When embedding shell code samples in SQL migration files, always use dollar-quoting (`$$`) or sanitize `'"'"'` → `''` before committing. Add a CI gate to catch it automatically.

---

Building in public: https://my-web-app-b67f4.web.app/

#PostgreSQL #Supabase #bash #buildinpublic #GitHubActions
