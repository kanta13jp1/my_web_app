# bc58b50b #1781: SubagentStop hook — output quality gate
# Fires when a subagent finishes (v2.1.126+)
# Checks for dummy data, migration timestamp format issues, critical rule violations

param()

$agentType   = $env:CLAUDE_SUBAGENT_TYPE
if (-not $agentType) { $agentType = $env:CLAUDE_AGENT_TYPE }
$lastMessage = $env:CLAUDE_LAST_ASSISTANT_MESSAGE
$timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Log subagent stop
$logFile = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks\subagent-log.txt"
try {
    $preview = if ($lastMessage) { $lastMessage.Substring(0, [Math]::Min(80, $lastMessage.Length)) } else { "(empty)" }
    Add-Content -Path $logFile -Value "[$timestamp] SubagentStop: type=$agentType output_preview=$preview" -ErrorAction SilentlyContinue
} catch { }

if (-not $lastMessage) { exit 0 }

try {
    $issues = @()

    # Check 1: dummy data patterns
    $dummyPatterns = @('lorem ipsum', 'fake.*data', 'dummy data', 'test.*placeholder', '// TODO:.*実装')
    foreach ($pattern in $dummyPatterns) {
        if ($lastMessage -imatch $pattern) {
            $issues += "ダミーデータ検出 (pattern: $pattern)"
        }
    }

    # Check 2: migration timestamp format — warn if wrong format seen
    $migrationRefs = [regex]::Matches($lastMessage, '\d{8}\d{2,6}_\w+\.sql')
    foreach ($m in $migrationRefs) {
        $fn = $m.Value
        if ($fn -notmatch '^\d{14}_') {
            $issues += "Migration timestamp 形式不正: $fn (正: YYYYMMDDXXXXXX_name.sql)"
        }
    }

    # Check 3: --no-verify in git commit
    if ($lastMessage -imatch 'git commit.*--no-verify|git push.*--force') {
        $issues += "危険なgitコマンド検出: --no-verify or --force"
    }

    if ($issues.Count -gt 0) {
        $issueList = ($issues -join ' / ') -replace '"', "'"
        $ctx = "SubagentStop quality gate: ${issueList}. 問題を修正してから完了としてください。"
        $output = "{`"hookSpecificOutput`":{`"additionalContext`":`"$ctx`"}}"
        Write-Output $output
    }
} catch {
    # Never block on hook error
}
exit 0
