#!/usr/bin/env python3
# Update COMPRESSED_PROMPT_V3.md instance section
import re, sys

path = 'C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/frosty-hamilton/.github/COMPRESSED_PROMPT_V3.md'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# ---- Find section boundaries ----
start_marker = '## \U0001f500 4\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9 + Multi-AI'
end_marker = '\n---\n\n## \U0001f3c6 \u7af6\u540821\u793e'

start_idx = content.find(start_marker)
end_idx   = content.find(end_marker, start_idx)

if start_idx < 0 or end_idx < 0:
    print(f'ERROR: markers not found (start={start_idx}, end={end_idx})')
    sys.exit(1)

print(f'Replacing chars {start_idx}..{end_idx}')

new_section = '''\
## \U0001f500 4\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9 + Multi-AI \u4e26\u884c\u958b\u767a\u30b9\u30b3\u30fc\u30d7\uff082026-04-16 \u66f4\u65b0\uff09

> \u8a73\u7d30\u5236\u7d04\u30ed\u30b0\u30fb\u6700\u65b0\u6a5f\u80fd\u30fb\u6b21\u56de\u63a8\u5968\u30d7\u30ed\u30f3\u30d7\u30c8: **`docs/instance-constraints.md`** \u53c2\u7167\u3002
> \u65b0\u5236\u7d04\u767a\u898b\u6642\u306f\u305d\u306e\u30d5\u30a1\u30a4\u30eb\u306b\u5373\u8ffd\u8a18\u3057\u3001\u3053\u306e\u8868\u306e\u5236\u7d04\u5217\u3082\u540c\u6642\u66f4\u65b0\u3059\u308b\u3053\u3068\u3002

### Claude Code 4\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9\u69cb\u6210

| \u30a4\u30f3\u30b9\u30bf\u30f3\u30b9 | \u62c5\u5f53\u7bc4\u56f2 | \u63a8\u5968\u30e2\u30c7\u30eb | \u63a8\u5968\u30e2\u30fc\u30c9 | \u4e3b\u306a\u5236\u7d04 |
| --- | --- | --- | --- | --- |
| **VSCode\u7248** | `lib/` + `supabase/functions/` + `docs/DESIGN.md` | `claude-sonnet-4-6` | \u901a\u5e38\u3002\u8907\u96d1UI\u8a2d\u8a08\u6642 **Extended Thinking** | \u306a\u3057 |
| **Windows\u30a2\u30d7\u30ea\u7248** | `docs/` + `supabase/migrations/` + notebooklm CLI\u5c02\u4efb | `claude-sonnet-4-6` | \u901a\u5e38 + CAVEMAN | `PYTHONUTF8=1` \u5fc5\u9808 / xlsx\u30ed\u30c3\u30af\u6ce8\u610f |
| **PowerShell\u7248** | `.github/workflows/` + `.mcp.json` | \u5b9a\u578b: `haiku-4-5` / \u8a2d\u8a08: `sonnet-4-6` | `/fast` (\u5b9a\u578b) / \u901a\u5e38 (\u8a2d\u8a08) | GHA `${{}}` \u306f env:\u30d6\u30ed\u30c3\u30af\u7d4c\u7531 |
| **WEB\u7248** | `docs/blog-drafts/` + `docs/competitor-reports/` + GitHub PR/Issues | `claude-sonnet-4-6` | **Projects + Memory + Learning Mode** | notebooklm / flutter analyze / deno lint / \u30ed\u30fc\u30ab\u30ebCLI \u4e0d\u53ef |

### Claude \u6700\u65b0\u6a5f\u80fd \u6d3b\u7528\u30ac\u30a4\u30c9

| \u6a5f\u80fd | \u5bfe\u5fdc\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9 | \u4f7f\u3044\u6240 |
| --- | --- | --- |
| **Extended Thinking** | VSCode / Windows\u30a2\u30d7\u30ea | \u8907\u96d1UI\u8a2d\u8a08\u30fbDB schema\u30fb\u30a2\u30fc\u30ad\u30c6\u30af\u30c1\u30e3\u6c7a\u5b9a\u3002`claude-opus-4` \u63a8\u5968 |
| **Projects\u6a5f\u80fd** | WEB\u7248 (claude.ai\u5c02\u7528) | \u30d7\u30ed\u30b8\u30a7\u30af\u30c8\u6587\u8108\u30fbCLAUDE.md\u30fb\u5c65\u6b74\u3092\u30bb\u30c3\u30b7\u30e7\u30f3\u8d8a\u3048\u3067\u6c38\u7d9a\u5316 |
| **Memory\u6a5f\u80fd** | WEB\u7248 (claude.ai\u5c02\u7528) | \u30e6\u30fc\u30b6\u30fc\u8a2d\u5b9a\u30fb\u30d7\u30ed\u30b8\u30a7\u30af\u30c8\u30b3\u30f3\u30c6\u30ad\u30b9\u30c8\u30fb\u3088\u304f\u4f7f\u3046\u30d1\u30bf\u30fc\u30f3\u3092\u8a18\u61b6 |
| **Learning Mode** | WEB\u7248 (Projects\u7d4c\u7531) | Projects\u306b\u30ea\u30dd\u30b8\u30c8\u30ea\u30de\u30c3\u30d7\u30fbCLAUDE.md\u3092\u8aad\u307e\u305b\u308b\u3068\u6b21\u56de\u304b\u3089\u30b3\u30f3\u30c6\u30ad\u30b9\u30c8\u521d\u671f\u5316\u4e0d\u8981 |
| **Interleaved Thinking** | \u5168\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9 | \u30c4\u30fc\u30eb\u5b9f\u884c\u4e2d\u306b\u3082\u601d\u8003\u3092\u7d99\u7d9a\u3002\u591a\u30b9\u30c6\u30c3\u30d7\u30bf\u30b9\u30af\u3067\u81ea\u52d5\u9069\u7528 |
| **CAVEMAN\u30e2\u30fc\u30c9** | Windows\u30a2\u30d7\u30ea / PowerShell \u4e3b\u4f53 | \u30b3\u30df\u30e5\u30cb\u30b1\u30fc\u30b7\u30e7\u30f3\u30c8\u30fc\u30af\u30f3\uff5e75%\u524a\u6e1b |

### \u5916\u90e8AI \u6700\u65b0\u30e2\u30c7\u30eb\u30fb\u6a5f\u80fd

| AI | \u6700\u65b0\u30e2\u30c7\u30eb | \u4e3b\u306a\u6a5f\u80fd | \u3053\u306e\u30d7\u30ed\u30b8\u30a7\u30af\u30c8\u3067\u306e\u7528\u9014 |
| --- | --- | --- | --- |
| **GitHub Copilot** | GPT-4o / Claude Sonnet / Gemini Pro \u9078\u62e9\u53ef | Inline\u88dc\u5b8c / Copilot Edits (\u8907\u6570\u30d5\u30a1\u30a4\u30eb\u540c\u6642\u7de8\u96c6) / Copilot Workspace (Issue\u2192PR\u81ea\u52d5) / `@workspace` | VSCode\u7248: Edits\u3067Flutter\u591a\u30d5\u30a1\u30a4\u30eb\u7de8\u96c6 / PS\u7248: `gh copilot suggest` |
| **Gemini Code Assist** | Gemini 2.5 Pro (2M\u30c8\u30fc\u30af\u30f3) / Flash | Agent mode / Flutter/Dart\u7279\u5316 / \u5927\u898f\u6a21\u30ea\u30d5\u30a1\u30af\u30bf | EF\u5168\u4f53\u6a2a\u65ad\u5206\u6790 / Dart\u5927\u898f\u6a21\u30ea\u30d5\u30a1\u30af\u30bf |
| **OpenAI CODEX** | o3 (\u6700\u5f37\u63a8\u8ad6) / o4-mini (\u9ad8\u901f\u4f4e\u30b3\u30b9\u30c8) / Codex CLI | SQL\u6700\u9069\u5316 / \u30a2\u30eb\u30b4\u30ea\u30ba\u30e0 / \u30bf\u30fc\u30df\u30ca\u30eb\u76f4\u5b9f\u884c | Supabase\u30af\u30a8\u30ea\u6700\u9069\u5316 / PS\u7248: `codex` CLI |

### AI\u9078\u629e\u30d5\u30ed\u30fc

```text
\u884c\u30ec\u30d9\u30eb\u88dc\u5b8c                  -> GitHub Copilot Inline (Ctrl+Enter)
\u8907\u6570\u30d5\u30a1\u30a4\u30eb\u540c\u6642\u7de8\u96c6 (VSCode)    -> Copilot Edits
\u8907\u96d1\u306aDart/Flutter              -> Gemini 2.5 Pro (\u9577\u30b3\u30f3\u30c6\u30ad\u30b9\u30c8+Flutter\u7279\u5316)
SQL / \u30a2\u30eb\u30b4\u30ea\u30ba\u30e0\u6700\u9069\u5316          -> CODEX o3/o4-mini
\u8a2d\u8a08\u30fb\u6226\u7565\u30fb\u9577\u671f\u5224\u65ad            -> Claude Code (Memory + ROADMAP)
\u8907\u96d1\u306a\u63a8\u8ad6\u30fb\u30a2\u30fc\u30ad\u30c6\u30af\u30c1\u30e3       -> Claude Extended Thinking (opus/sonnet)
\u30d6\u30ed\u30b0 / \u7af6\u5408\u30ea\u30b5\u30fc\u30c1           -> WEB\u7248 (WebSearch/WebFetch/Projects)
NotebookLM Deep Research      -> Windows\u30a2\u30d7\u30ea\u7248\u5c02\u4efb (notebooklm CLI)
Issue -> PR \u5168\u81ea\u52d5              -> Copilot Workspace
```

### \u5236\u7d04\u767a\u898b\u6642\u306e\u66f4\u65b0\u30d5\u30ed\u30fc\uff08\u5168\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9\u5171\u901a\uff09

```text
Step 1: docs/instance-constraints.md \u306e\u300c\u5236\u7d04\u767a\u898b\u30ed\u30b0\u300d\u306b\u8ffd\u8a18
Step 2: \u3053\u306e\u8868\u306e\u5236\u7d04\u5217\u3092\u66f4\u65b0
Step 3: memory/feedback_correction_YYYYMMDD.md \u306b\u8a18\u9332
Step 4: cross-instance-pr \u3067\u4ed6\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9\u3078\u5468\u77e5
```

### \u30af\u30aa\u30fc\u30bf\u76e3\u8996 (quota-monitor.yml \u6bce\u65e5 09:00 JST)

| \u30c4\u30fc\u30eb | \u76e3\u8996\u65b9\u6cd5 | \u30a2\u30e9\u30fc\u30c8\u9583\u5024 |
| --- | --- | --- |
| Claude (Anthropic API) | `/v1/usage` | \u6708\u6b21 $50 |
| OpenAI (CODEX) | `/v1/usage` | \u6708\u6b21 $20 |
| Gemini Code Assist | Google Cloud Monitoring | \u6708\u6b21\u30af\u30aa\u30fc\u30bf 80% |
| GitHub Copilot | `/user/copilot_billing` | \u30b7\u30fc\u30c8\u6570\u4e0a\u9650\u8fd1\u63a5 |

**\u7dca\u6025\u6a2a\u65ad\u6a29\u9650**: blocking \u6642\u306f `docs/cross-instance-prs/YYYYMMDD_<\u5185\u5bb9>.md` \u306b\u63d0\u6848\u3092\u30b3\u30df\u30c3\u30c8\u3002\u62c5\u5f53\u30a4\u30f3\u30b9\u30bf\u30f3\u30b9\u304c\u6b21\u30bb\u30c3\u30b7\u30e7\u30f3\u3067\u63a1\u5426\u3002
**\u7af6\u5408\u56de\u907f\u30d1\u30bf\u30fc\u30f3**: `git stash -> git pull --rebase origin main -> git push -> git stash pop`\
'''

content = content[:start_idx] + new_section + content[end_idx:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Done. New content length: {len(content)}')
