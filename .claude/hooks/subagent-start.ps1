# bc58b50b #1781: SubagentStart hook — inject project constraints into subagent context
# Fires when a subagent begins execution (v2.1.126+)
# Outputs additionalContext with key project rules for the subagent

param()

$agentType = $env:CLAUDE_SUBAGENT_TYPE
if (-not $agentType) { $agentType = $env:CLAUDE_AGENT_TYPE }

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Log subagent start
$logFile = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks\subagent-log.txt"
try {
    Add-Content -Path $logFile -Value "[$timestamp] SubagentStart: type=$agentType" -ErrorAction SilentlyContinue
} catch { }

# Inject key project constraints as additionalContext
# These are the most critical rules that subagents must follow
$constraints = @"
自分株式会社プロジェクト制約 (SubagentStart injection):
1. [REAL-DATA] ダミーデータ禁止 — Supabase実データのみ使用
2. [EF-CAP-50] Supabase Edge Function は50本以内 (現在~20本)
3. [DART-FORMAT] Dart編集後: dart format → flutter analyze 0 errors → push
4. [MIGRATION] SQLファイル命名: YYYYMMDDXXXXXX_descriptive_name.sql (timestamp重複禁止)
5. [NO-SCOPE-CREEP] 明示依頼のない機能追加禁止
6. [EF-FIRST] 複雑ロジックはEdge Function優先 (フロントに置かない)
Instance: PS#5 (CI/automation/hooks territory)
"@

$ctx = $constraints -replace '"', "'" -replace "`n", " | "
$output = "{`"hookSpecificOutput`":{`"additionalContext`":`"$ctx`"}}"
Write-Output $output
exit 0
