# bc58b50b #1781 / #2535: SubagentStop hook - output quality gate
# Fires when a subagent finishes and returns compact corrective context.

param()

$agentType = $env:CLAUDE_SUBAGENT_TYPE
if (-not $agentType) { $agentType = $env:CLAUDE_AGENT_TYPE }
$lastMessage = $env:CLAUDE_LAST_ASSISTANT_MESSAGE
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$logFile = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks\subagent-log.txt"
try {
    $preview = if ($lastMessage) { $lastMessage.Substring(0, [Math]::Min(80, $lastMessage.Length)) } else { "(empty)" }
    Add-Content -Path $logFile -Value "[$timestamp] SubagentStop: type=$agentType output_preview=$preview" -ErrorAction SilentlyContinue
} catch { }

if (-not $lastMessage) { exit 0 }

try {
    $issues = @()

    $dummyPatterns = @(
        'lorem ipsum',
        'fake.*data',
        'dummy data',
        'test.*placeholder',
        '// TODO:'
    )
    foreach ($pattern in $dummyPatterns) {
        if ($lastMessage -imatch $pattern) {
            $issues += "Dummy/test placeholder pattern detected: $pattern"
        }
    }

    $migrationRefs = [regex]::Matches($lastMessage, '\d{8}\d{2,6}_\w+\.sql')
    foreach ($m in $migrationRefs) {
        $fn = $m.Value
        if ($fn -notmatch '^\d{14}_') {
            $issues += "Migration timestamp format issue: $fn (expected YYYYMMDDXXXXXX_name.sql)"
        }
    }

    if ($lastMessage -imatch 'git commit.*--no-verify|git push.*--force') {
        $issues += "Dangerous git command detected: --no-verify or --force"
    }

    $contractTerms = @('role', 'scope', 'validation', 'risk', 'cleanup')
    foreach ($term in $contractTerms) {
        if ($lastMessage -inotmatch $term) {
            $issues += "Subagent return contract missing: $term"
        }
    }

    if ($lastMessage -imatch 'production write|secret|service_role|long-lived dev server|reactivate.*Codex #2|reactivate.*Codex #3') {
        $issues += "Subagent guardrail risk: production/secrets/long-lived process/dormant lane language detected"
    }

    if ($issues.Count -gt 0) {
        $issueList = ($issues -join ' / ') -replace '"', "'"
        $ctx = "SubagentStop quality gate: ${issueList}. Fix the issue before treating the subagent result as complete."
        $output = "{`"hookSpecificOutput`":{`"additionalContext`":`"$ctx`"}}"
        Write-Output $output
    }
} catch {
    # Never block on hook error.
}
exit 0
