# bc58b50b #1752: Notification hook — idle/permission_prompt アラート
# Fires async when Claude needs attention (idle or permission waiting)

param()

$reason = $env:CLAUDE_NOTIFICATION_REASON
$toolName = $env:CLAUDE_TOOL_NAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logFile = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks\notification-log.txt"

# Always log to file
$logMsg = "[$timestamp] Notification: reason=$reason tool=$toolName"
try {
    Add-Content -Path $logFile -Value $logMsg -ErrorAction SilentlyContinue
} catch { }

# Windows Toast notification (native, no external deps)
try {
    $title = "Claude Code"
    $body = switch ($reason) {
        "idle_prompt" { "エージェント待機中 — 入力が必要です" }
        "permission_prompt" { "権限承認待ち — 確認してください" }
        default { "通知: $reason" }
    }

    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
        [Windows.UI.Notifications.ToastTemplateType]::ToastText02
    )
    $template.GetElementsByTagName("text")[0].InnerText = $title
    $template.GetElementsByTagName("text")[1].InnerText = $body

    $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code")
    $notifier.Show($toast)
} catch { }

# Slack notification (if SLACK_WEBHOOK_URL is set locally)
$slackUrl = $env:SLACK_WEBHOOK_URL
if ($slackUrl) {
    try {
        $emoji = if ($reason -eq "permission_prompt") { ":warning:" } else { ":hourglass_flowing_sand:" }
        $payload = @{
            text = "$emoji Claude Code $reason on $(hostname) at $timestamp"
        } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $slackUrl -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    } catch { }
}

exit 0
