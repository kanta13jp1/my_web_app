# [cross-instance-pr] VSCode版 開発環境 緊急 troubleshoot — Flutter engine + Deno LSP + 1K problems

**To**: VSCode版 (= 自環境問題)
**From**: Win版#132 part 125
**Priority**: high
**Date**: 2026-05-04
**Issue**: [#1962](https://github.com/kanta13jp1/my_web_app/issues/1962)

## 状況

User screenshot (= VS Code window 表示) で 3 系統同時発生確認:

1. Flutter Initialization → exit 1 (= "Unable to determine engine version" + CP932 文字化け)
2. Deno Language Server EPIPE crash (= "Connection to server got closed. Server will not be restarted")
3. SCOREBOARD_2026-04-28.md (= 109 行 valid markdown) で 1000+ problems

## 即時対応 (= VSCode版 で実施)

### A. Deno LSP 再起動 (= 30 秒で完了)

```text
1. Ctrl+Shift+P → "Deno: Restart Language Server"
2. NG → VS Code 全体再起動 (Ctrl+Shift+P → "Reload Window")
3. NG → Deno extension reinstall (Extensions panel → Deno → Uninstall → Install)
4. 根本: Deno extension settings.json で version pin
   ```json
   "deno.version": "2.7.0"  // 2.7.12 で EPIPE bug 疑い
   ```
```

### B. Flutter 環境修復 (= 5 分)

```bash
# 1. PowerShell terminal で UTF-8 出力強制 (CP932 文字化け解消)
chcp 65001
$env:PYTHONUTF8 = "1"

# 2. Flutter doctor で root cause 確認
flutter doctor -v

# 3. engine version 取れない場合:
flutter clean
flutter pub get
flutter --version

# 4. 永続化: $PROFILE (PowerShell profile) に追記
"[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" | Out-File -Append $PROFILE
"`$env:PYTHONUTF8 = '1'" | Out-File -Append $PROFILE
```

### C. 1K problems (= A+B 解消後 phantom 消える期待)

```bash
# A+B 後も残る場合の実 lint チェック:
npx markdownlint docs/competitor-reports/SCOREBOARD_2026-04-28.md

# md ファイル自体は 109 行 valid UTF-8/CRLF と Win 側で確認済 →
# LSP cascade 由来 phantom が高確率
```

## 結果報告

完了したら本 PR を `done/` に移動 + Issue [#1962](https://github.com/kanta13jp1/my_web_app/issues/1962) に コメント:
- A 完了: ✅ / ❌ (= EPIPE 解消したか)
- B 完了: ✅ / ❌ (= flutter doctor が green か)
- C 完了: ✅ / ❌ (= problems 1K → 0 になったか)

## 関連

- 既存 Issue: [#1626](https://github.com/kanta13jp1/my_web_app/issues/1626) Codex #5 Windows Dart/Flutter プロセス分離
- 本 PR: cross-instance-pr 起票 (Win版#132 part 125)

## 連鎖防止

VSCode版環境異常時は以下を即実施:
1. **branch を kill して新 worktree** (= `bash .claude/scripts/setup-instance-worktree.sh vscode`)
2. **新 worktree でも同症状 → SDK/Extension 環境問題確定** → 本 PR 手順実施
3. **Win版/PS版 で代替** (= cross-instance-pr で UI task を Win/PS に handoff / docs/AI_FALLBACK_RUNBOOK.md 参照)
