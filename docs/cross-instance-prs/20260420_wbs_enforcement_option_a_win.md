# Win版 宛: Option A — SessionStart hook 自動 curl 強制

- **起票元**: PS版#2 S17 (2026-04-20)
- **優先度**: MEDIUM (Option C cron は既に稼働中なので強制の第 2 層)
- **起票理由**: ユーザー「すべてのインスタンス、セッションが必ず毎回こちらを更新するような仕組みは動作していますでしょうか?」への enforcement 強化。

## Context

- 現状の `[WBS-SYNC]` rule (`~/.claude/hooks/inject-rules.txt:65-74`) は **テキスト reminder のみ**。
- Claude が自発的に `wbs.priority_for_instance` を curl するかは任意 → 強制されていない。
- Option C (`wbs-staleness-audit.yml`) は 24h 遅延で検知するのみ。セッション内即時強制にならない。
- Option A = SessionStart hook で **hook 側が curl 済結果を system-reminder 注入** → Claude は結果を受け取るだけでサボれない。

## Win版 着手タスク

### 実装

`~/.claude/hooks/inject-rules.ps1` (既存) の SessionStart フックに以下ロジック追加:

```powershell
# Instance 判定 (worktree path から)
$cwd = (Get-Location).Path
$instance = switch -Wildcard ($cwd) {
  "*instance-vscode*" { "vscode" }
  "*instance-win*"    { "win" }
  "*instance-ps1*"    { "ps1" }
  "*instance-ps2*"    { "ps2" }
  "*instance-ps3*"    { "ps3" }
  "*instance-ps4*"    { "ps4" }
  "*instance-ps5*"    { "ps5" }
  "*instance-ps6*"    { "ps6" }
  default             { $null }
}

if ($instance) {
  $body = @{ action = "wbs.priority_for_instance"; instance = $instance } | ConvertTo-Json -Compress
  try {
    $resp = Invoke-RestMethod `
      -Uri "$env:SUPABASE_URL_PROD/functions/v1/tools-hub" `
      -Method POST `
      -Headers @{ Authorization = "Bearer $env:SUPABASE_ANON_KEY_PROD"; "Content-Type" = "application/json" } `
      -Body $body `
      -TimeoutSec 10
    # 結果を system-reminder 形式で stdout (hook 経由で Claude へ注入される)
    Write-Host "[WBS-SYNC-AUTO] instance=$instance top5:"
    $resp.tasks | Select-Object -First 5 | ForEach-Object {
      Write-Host "  - $($_.id) | $($_.title) | status=$($_.status) progress=$($_.progress)"
    }
  } catch {
    Write-Host "[WBS-SYNC-AUTO] fetch failed: $($_.Exception.Message) (非致死・次ターンで再試行)"
  }
}
```

### 環境変数

- `SUPABASE_URL_PROD` / `SUPABASE_ANON_KEY_PROD` は既に他 hook で使用中 (auto-capture.ps1 参照)。
- 無ければ `.env` / user secret から読込拡張。

### 効果

- SessionStart 毎に TOP 5 が自動注入 → Claude は自インスタンスの「今日何やるか」を知らない状態で開始できない。
- Option C cron (24h 遅延検知) と併用で defense-in-depth。

## 関連

- inject-rules.ps1: `~/.claude/hooks/inject-rules.ps1`
- EF: `supabase/functions/tools-hub/index.ts:883` (`wbs.priority_for_instance`)
- Option C: `.github/workflows/wbs-staleness-audit.yml`

## SLA

- 48h 以内着手 (INSTANCE-ROLES Rule)。実装後 `.claude/worktrees/instance-ps2` で動作確認可。


---

## 🚨 PREREQ FIX (PS#6 S22 2026-04-20 commit 232b2783)

本 handoff 着手の前に **tools-hub の wbs.* dispatch bug が修復された** ことを確認:

- **Bug**: `supabase/functions/tools-hub/index.ts` line 335 で wbs.* 全 9 actions が horseracing switch 内に誤ネスト → `startsWith("horseracing.")` false で unreachable → 401 Unauthorized silent fail (2 週間潜伏)
- **Fix**: line 335 の条件を `|| action.startsWith("wbs.")` で拡張 (commit 232b2783 main)
- **確認 curl**:
  ```bash
  curl -X POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub \
    -H "Authorization: Bearer <ANON_KEY>" -H "Content-Type: application/json" \
    -d "{\"action\":\"wbs.priority_for_instance\",\"instance\":\"ps6\"}"
  ```
  期待値: `{"success":true,"instance":"ps6","top_tasks":[...]}`

deploy-prod 反映まで最大 11 min × 並行数。反映確認後に本 handoff 作業着手可。

