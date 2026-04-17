---
title: "Claude Code VSCode Extension 60s Timeout: It Wasn't the MCPs"
tags: ClaudeCode,VSCode,debugging,AI,productivity
published: true
---

# Claude Code VSCode Extension 60s Timeout: It Wasn't the MCPs

## The Symptom

Every time I opened VSCode with the Claude Code extension (claude-vscode 2.1.112), I'd get:

```
Error: Subprocess initialization did not complete within 60000ms
— check authentication and network connectivity
```

Exactly 60 seconds after launch, it failed. The logs showed all MCP servers had connected fine. So what was blocking it?

## What I Tried First (Wrong Approach)

Assuming slow MCP server startup was the culprit, I removed them one by one by connection time:

| Removed | MCP | Connect time | Fixed? |
|---------|-----|-------------|--------|
| 1st | playwright | ~8s | ❌ |
| 2nd | magic | ~7s | ❌ |
| 3rd | code-review + github | ~5-6s | ❌ |

After removing 4 MCP servers, the timeout persisted.

## The Real Culprit

A `SessionStart` hook in `~/.claude/settings.json`:

```json
{
  "type": "command",
  "command": "sleep 600 && exit 2",
  "asyncRewake": true,
  "rewakeMessage": "10 minutes have passed. Check your progress."
}
```

**`asyncRewake: true` is not honored by the VSCode extension.**

In some Claude Code modes (terminal-based), this option runs the sleep asynchronously and injects a message after 600 seconds. But in the VSCode extension, this flag is ignored — `sleep 600` blocks the subprocess synchronously.

```
How the timeout happens:
  subprocess spawn
    → SessionStart hooks execute synchronously
      → sleep 600 starts blocking
        ← VSCode extension times out after 60 seconds
```

## The Fix

Remove the `sleep 600` hook from `~/.claude/settings.json`:

```diff
 "SessionStart": [
   {
     "hooks": [{"command": "powershell ...session-resume.ps1"}]
-  },
-  {
-    "hooks": [{
-      "command": "sleep 600 && exit 2",
-      "asyncRewake": true,
-      "rewakeMessage": "10 minutes have passed..."
-    }]
   }
 ]
```

After removing it, startup completes in 9 seconds:

```
14:35:18 spawn
14:35:27 "status":"ready" ✅  (9 seconds!)
14:35:36 first message received
```

## Why MCPs Were Irrelevant

In Claude Code 2.x, all MCP connections are fully asynchronous (non-blocking):

```
[MCP] --mcp-config servers running fully async (MCP_CONNECTION_NONBLOCKING)
```

Even if playwright takes 8 seconds to connect, it doesn't block the subprocess `ready` signal. Claude becomes responsive before MCPs finish connecting — tools become available as each MCP completes its handshake.

## TL;DR: Next Time You See This Timeout

Before removing MCPs, check `~/.claude/settings.json` `SessionStart` hooks first:

1. Any `sleep` or long-running commands in `SessionStart`?
2. `asyncRewake: true` behaves synchronously in the VSCode extension
3. MCPs are NONBLOCKING — removing them won't fix initialization timeouts

---
Building in public: <https://my-web-app-b67f4.web.app/>
#ClaudeCode #VSCode #debugging #buildinpublic
