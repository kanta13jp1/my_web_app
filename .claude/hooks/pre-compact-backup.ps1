# bc58b50b #1848: PreCompact hook — transcript backup before context compaction
# AI_FLEET_SYNERGY Principle #5: Memory & State Continuity Hooks
# Fires before Claude Code compacts the conversation context
# Saves compact summary to memory/transcripts/ for future session recovery

param()

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$datestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Summary injected by Claude Code before compact
$compactSummary  = $env:CLAUDE_COMPACT_TRIGGER_SUMMARY
$projectDir      = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = Get-Location }

# Target directory: project memory/transcripts/
$transcriptDir = Join-Path $projectDir "memory\transcripts"
if (-not (Test-Path $transcriptDir)) {
    New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null
}

$outFile = Join-Path $transcriptDir "compact-$timestamp.md"

try {
    $content = @"
# Compact Backup — $datestamp

## Summary (AI-generated before compact)
$compactSummary

## Recovery Notes
- Restore context: read this file at session start
- Search memory: \`mem-search\` skill or \`get_observations\` for related session IDs
- Project: my_web_app (Flutter Web + Supabase)
- Instance: PS#5 (CI/automation/hooks)

## Key Reference Files
- \`.claude/settings.json\` — hook config, MCP settings
- \`docs/GROWTH_STRATEGY_ROADMAP.md\` — session history
- \`memory/MEMORY.md\` — memory index
- \`docs/MULTI_INSTANCE_FLEET.md\` — 12-instance fleet config
"@
    [System.IO.File]::WriteAllText($outFile, $content, [System.Text.Encoding]::UTF8)

    # Log to hook log
    $logFile = Join-Path $projectDir "memory\compact-log.txt"
    Add-Content -Path $logFile -Value "[$datestamp] PreCompact backup: $outFile" -ErrorAction SilentlyContinue
} catch {
    # Never block on hook error
}

exit 0
