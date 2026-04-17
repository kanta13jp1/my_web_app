---
title: "Claude Code VSCode拡張 60秒タイムアウトの真犯人 — MCP削除より先に確認すべきこと"
tags: ClaudeCode,VSCode,個人開発,AI,デバッグ
published: true
---

# Claude Code VSCode拡張 60秒タイムアウトの真犯人

## エラーの症状

VSCode の Claude Code 拡張 (claude-vscode 2.1.112) を起動すると毎回タイムアウト:

```
Error: Subprocess initialization did not complete within 60000ms
— check authentication and network connectivity
```

起動後ちょうど60秒で失敗。ログを見ると MCP サーバーは全て正常接続済みなのに…。

## 最初に疑ったこと (間違い)

MCP サーバーの起動が遅いせいだろうと思い、接続時間の長い順に削除:

| 削除順 | MCP | 接続時間 | 効果 |
|-------|-----|---------|------|
| 1 | playwright | ~8s | ❌ |
| 2 | magic | ~7s | ❌ |
| 3 | code-review + github | ~5-6s | ❌ |

4本削除してもタイムアウトが続いた。

## 真犯人はこれだった

`~/.claude/settings.json` の `SessionStart` フック:

```json
{
  "type": "command",
  "command": "sleep 600 && exit 2",
  "asyncRewake": true,
  "rewakeMessage": "10分経過しました。作業を確認してください。"
}
```

**`asyncRewake: true` が VSCode拡張では尊重されない。**

このオプションは Claude Code の一部モード (ターミナル版等) では「sleep を非同期で実行し、600秒後に rewakeMessage を注入する」という意図で動作する。しかし VSCode拡張ではこのオプションが無視され、`sleep 600` が subprocess を同期ブロックし続ける。

```
タイムアウトの仕組み:
  subprocess spawn
    → SessionStart hooks を同期実行
      → sleep 600 が実行開始
        ← 60秒後に VSCode 拡張がタイムアウト
```

## 解決方法

`~/.claude/settings.json` から `sleep 600` フックを削除するだけ:

```diff
 "SessionStart": [
   {
     "hooks": [{"command": "powershell ...session-resume.ps1"}]
-  },
-  {
-    "hooks": [{
-      "command": "sleep 600 && exit 2",
-      "asyncRewake": true,
-      "rewakeMessage": "10分経過しました..."
-    }]
   }
 ]
```

削除後、起動が 9秒で完了:

```
14:35:18 spawn
14:35:27 "status":"ready" ✅  (←9秒)
14:35:36 user message received
```

## なぜ MCP が無関係だったのか

Claude Code 2.x の MCP 接続はすべて非同期 (non-blocking):

```
[MCP] --mcp-config servers running fully async (MCP_CONNECTION_NONBLOCKING)
```

playwright が 8秒かかっても subprocess の `ready` シグナルをブロックしない。MCP の接続完了を待たずに Claude は応答可能になる。接続が完了次第、各ツールが順次有効になる仕組み。

## まとめ: 次回タイムアウトが起きたら

MCPを疑う前に `~/.claude/settings.json` の `SessionStart` フックを確認しよう:

1. `SessionStart` に `sleep` や長時間コマンドがないか
2. `asyncRewake: true` は VSCode拡張では同期扱いになる
3. MCP は NONBLOCKING — 削除しても効果なし

---
自分株式会社: <https://my-web-app-b67f4.web.app/>
#ClaudeCode #VSCode #個人開発 #デバッグ
