<#
.SYNOPSIS
Diagnoses Windows console, stale shell process, and WSL default issues.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/windows_terminal_doctor.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/windows_terminal_doctor.ps1 -Json

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/windows_terminal_doctor.ps1 -OfferStop -Confirm
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [ValidateRange(5, 10080)]
    [int]$MinimumAgeMinutes = 120,

    [ValidateRange(1, 30)]
    [int]$SampleSeconds = 2,

    [switch]$OfferStop,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:VSCodeTerminalHelp = "https://code.visualstudio.com/docs/supporting/troubleshoot-terminal-launch"
$script:LegacyConsoleHelp = "https://learn.microsoft.com/windows/console/legacymode"
$script:WslHelp = "https://learn.microsoft.com/windows/wsl/basic-commands"

function Get-LegacyConsoleAssessment {
    [CmdletBinding()]
    param([AllowNull()][object]$ForceV2)

    if ($null -eq $ForceV2) {
        return [pscustomobject]@{
            ForceV2 = $null
            IsLegacy = $false
            Status = "default-modern"
            Message = "HKCU:\Console\ForceV2 is not set; Windows uses the modern console default."
        }
    }

    try {
        $value = [int]$ForceV2
    } catch {
        return [pscustomobject]@{
            ForceV2 = [string]$ForceV2
            IsLegacy = $false
            Status = "unknown"
            Message = "HKCU:\Console\ForceV2 is not a recognized DWORD value."
        }
    }

    if ($value -eq 0) {
        return [pscustomobject]@{
            ForceV2 = $value
            IsLegacy = $true
            Status = "legacy-enabled"
            Message = "Legacy console mode is enabled globally (ForceV2=0)."
        }
    }

    if ($value -eq 1) {
        return [pscustomobject]@{
            ForceV2 = $value
            IsLegacy = $false
            Status = "modern-enabled"
            Message = "Modern console features are enabled (ForceV2=1)."
        }
    }

    return [pscustomobject]@{
        ForceV2 = $value
        IsLegacy = $false
        Status = "unknown"
        Message = "HKCU:\Console\ForceV2 has an unsupported value: $value."
    }
}

function Read-LegacyConsoleForceV2 {
    [CmdletBinding()]
    param()

    try {
        return Get-ItemPropertyValue `
            -LiteralPath "HKCU:\Console" `
            -Name "ForceV2" `
            -ErrorAction Stop
    } catch [System.Management.Automation.ItemNotFoundException] {
        return $null
    } catch [System.Management.Automation.PSArgumentException] {
        return $null
    }
}

function Get-WslDefaultFromLegacyOutput {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$OutputText)

    if ([string]::IsNullOrWhiteSpace($OutputText)) {
        return $null
    }

    $normalized = $OutputText.Replace("`0", "")
    foreach ($line in ($normalized -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match "^(?<name>.+?)\s+\((?:Default|既定|既定値)\)\s*$") {
            return $Matches["name"].Trim()
        }
    }

    return $null
}

function Get-WslDefaultAssessment {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$WslConfigOutput,
        [AllowNull()][string]$RegistryDefault
    )

    $parsedDefault = Get-WslDefaultFromLegacyOutput -OutputText $WslConfigOutput
    if (-not [string]::IsNullOrWhiteSpace($parsedDefault)) {
        $defaultDistribution = $parsedDefault
        $source = "wslconfig.exe /l"
    } elseif (-not [string]::IsNullOrWhiteSpace($RegistryDefault)) {
        $defaultDistribution = $RegistryDefault.Trim()
        $source = "HKCU Lxss registry fallback"
    } else {
        $defaultDistribution = $null
        $source = "unavailable"
    }

    $isDockerInternal = $false
    if ($null -ne $defaultDistribution) {
        $isDockerInternal = $defaultDistribution -match "^(?i:docker-desktop(?:-data)?)$"
    }

    if ($isDockerInternal) {
        $status = "invalid-docker-default"
        $message = "Docker Desktop internal distribution '$defaultDistribution' is the WSL default. Select an interactive Linux distribution."
    } elseif ($null -eq $defaultDistribution) {
        $status = "unknown"
        $message = "The default WSL distribution could not be determined."
    } else {
        $status = "interactive-default"
        $message = "The WSL default is '$defaultDistribution'."
    }

    return [pscustomobject]@{
        DefaultDistribution = $defaultDistribution
        Source = $source
        IsDockerInternal = $isDockerInternal
        Status = $status
        Message = $message
    }
}

function Read-WslRegistryDefault {
    [CmdletBinding()]
    param()

    $lxssPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    try {
        $defaultId = Get-ItemPropertyValue `
            -LiteralPath $lxssPath `
            -Name "DefaultDistribution" `
            -ErrorAction Stop
        $idText = [string]$defaultId
        if ($idText -notmatch "^\{") {
            $idText = ([guid]$idText).ToString("B")
        }
        return Get-ItemPropertyValue `
            -LiteralPath (Join-Path $lxssPath $idText) `
            -Name "DistributionName" `
            -ErrorAction Stop
    } catch {
        return $null
    }
}

function Read-WslConfigOutput {
    [CmdletBinding()]
    param()

    if (-not (Get-Command "wslconfig.exe" -ErrorAction SilentlyContinue)) {
        return ""
    }

    try {
        return (& wslconfig.exe /l 2>&1 | Out-String)
    } catch {
        return ""
    }
}

function Get-WindowsProcessSnapshot {
    [CmdletBinding()]
    param()

    return @(
        Get-CimInstance Win32_Process | ForEach-Object {
            $creationTime = $null
            if ($null -ne $_.CreationDate) {
                $creationTime = [datetime]$_.CreationDate
            }
            [pscustomobject]@{
                Name = [string]$_.Name
                ProcessId = [int]$_.ProcessId
                ParentProcessId = [int]$_.ParentProcessId
                CreationTime = $creationTime
                CpuTicks = ([uint64]$_.KernelModeTime + [uint64]$_.UserModeTime)
            }
        }
    )
}

function Get-ProtectedProcessIds {
    [CmdletBinding()]
    param(
        [object[]]$Processes,
        [int]$CurrentProcessId
    )

    $byId = @{}
    foreach ($process in $Processes) {
        $byId[[int]$process.ProcessId] = $process
    }

    $protected = New-Object System.Collections.Generic.List[int]
    $candidateId = $CurrentProcessId
    while ($candidateId -gt 0 -and -not $protected.Contains($candidateId)) {
        $protected.Add($candidateId)
        if (-not $byId.ContainsKey($candidateId)) {
            break
        }
        $candidateId = [int]$byId[$candidateId].ParentProcessId
    }

    return @($protected)
}

function Get-StaleShellProcessCandidates {
    [CmdletBinding()]
    param(
        [object[]]$FirstSnapshot,
        [object[]]$SecondSnapshot,
        [datetime]$Now,
        [int]$MinimumAgeMinutes,
        [int[]]$ProtectedProcessIds = @()
    )

    $allowedNames = @("powershell", "pwsh", "wsl")
    $firstById = @{}
    foreach ($process in $FirstSnapshot) {
        $firstById[[int]$process.ProcessId] = $process
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($process in $SecondSnapshot) {
        $processId = [int]$process.ProcessId
        $name = ([string]$process.Name).ToLowerInvariant() -replace "\.exe$", ""
        if ($allowedNames -notcontains $name) {
            continue
        }
        if ($ProtectedProcessIds -contains $processId) {
            continue
        }
        if (-not $firstById.ContainsKey($processId)) {
            continue
        }

        $previous = $firstById[$processId]
        if ([uint64]$previous.CpuTicks -ne [uint64]$process.CpuTicks) {
            continue
        }
        if ($null -eq $process.CreationTime) {
            continue
        }

        $age = $Now - [datetime]$process.CreationTime
        if ($age.TotalMinutes -lt $MinimumAgeMinutes) {
            continue
        }

        $results.Add([pscustomobject]@{
            Name = $name
            ProcessId = $processId
            ParentProcessId = [int]$process.ParentProcessId
            AgeMinutes = [math]::Floor($age.TotalMinutes)
            CpuChangedDuringSample = $false
        })
    }

    return @($results | Sort-Object AgeMinutes -Descending)
}

function Invoke-WindowsTerminalDoctor {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [int]$MinimumAgeMinutes,
        [int]$SampleSeconds,
        [switch]$OfferStop
    )

    if ($env:OS -ne "Windows_NT") {
        return [pscustomobject]@{
            Status = "skipped-non-windows"
            LegacyConsole = $null
            Wsl = $null
            StaleProcessCandidates = @()
            StoppedProcessIds = @()
            References = @($script:VSCodeTerminalHelp, $script:LegacyConsoleHelp, $script:WslHelp)
        }
    }

    $legacy = Get-LegacyConsoleAssessment -ForceV2 (Read-LegacyConsoleForceV2)
    $wsl = Get-WslDefaultAssessment `
        -WslConfigOutput (Read-WslConfigOutput) `
        -RegistryDefault (Read-WslRegistryDefault)

    $firstSnapshot = Get-WindowsProcessSnapshot
    Start-Sleep -Seconds $SampleSeconds
    $secondSnapshot = Get-WindowsProcessSnapshot
    $protectedIds = Get-ProtectedProcessIds `
        -Processes $secondSnapshot `
        -CurrentProcessId $PID
    $candidates = @(
        Get-StaleShellProcessCandidates `
            -FirstSnapshot $firstSnapshot `
            -SecondSnapshot $secondSnapshot `
            -Now (Get-Date) `
            -MinimumAgeMinutes $MinimumAgeMinutes `
            -ProtectedProcessIds $protectedIds
    )

    $stopped = New-Object System.Collections.Generic.List[int]
    if ($OfferStop) {
        foreach ($candidate in $candidates) {
            $target = "$($candidate.Name) PID $($candidate.ProcessId), idle for at least $SampleSeconds seconds, age $($candidate.AgeMinutes) minutes"
            if ($PSCmdlet.ShouldProcess($target, "Stop stale shell candidate")) {
                Stop-Process -Id $candidate.ProcessId -ErrorAction Stop
                $stopped.Add([int]$candidate.ProcessId)
            }
        }
    }

    $hasFinding = $legacy.IsLegacy -or $wsl.IsDockerInternal -or $candidates.Count -gt 0
    return [pscustomobject]@{
        Status = $(if ($hasFinding) { "warning" } else { "ok" })
        LegacyConsole = $legacy
        Wsl = $wsl
        StaleProcessCandidates = @($candidates)
        StoppedProcessIds = @($stopped)
        References = @($script:VSCodeTerminalHelp, $script:LegacyConsoleHelp, $script:WslHelp)
    }
}

function Show-WindowsTerminalDoctorResult {
    [CmdletBinding()]
    param(
        [object]$Result,
        [switch]$AsJson,
        [switch]$StopWasOffered
    )

    if ($AsJson) {
        $Result | ConvertTo-Json -Depth 6
        return
    }

    Write-Host "Windows terminal doctor: $($Result.Status)"
    if ($Result.Status -eq "skipped-non-windows") {
        Write-Host "This diagnostic only runs on Windows."
    } else {
        Write-Host "Legacy console: $($Result.LegacyConsole.Message)"
        Write-Host "WSL default: $($Result.Wsl.Message)"
        if ($Result.StaleProcessCandidates.Count -gt 0) {
            Write-Host ""
            Write-Host "Idle shell candidates (not proof of a hang):" -ForegroundColor Yellow
            $Result.StaleProcessCandidates | Format-Table Name, ProcessId, ParentProcessId, AgeMinutes -AutoSize
            if (-not $StopWasOffered) {
                Write-Host "Review ownership and work first. To confirm each stop interactively, rerun with -OfferStop -Confirm." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Idle shell candidates: none"
        }
    }

    Write-Host ""
    Write-Host "Official references:"
    foreach ($reference in $Result.References) {
        Write-Host "- $reference"
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    $invokeParameters = @{
        MinimumAgeMinutes = $MinimumAgeMinutes
        SampleSeconds = $SampleSeconds
        OfferStop = $OfferStop
    }
    if ($PSBoundParameters.ContainsKey("WhatIf")) {
        $invokeParameters["WhatIf"] = $PSBoundParameters["WhatIf"]
    }
    if ($PSBoundParameters.ContainsKey("Confirm")) {
        $invokeParameters["Confirm"] = $PSBoundParameters["Confirm"]
    }

    $doctorResult = Invoke-WindowsTerminalDoctor @invokeParameters
    Show-WindowsTerminalDoctorResult `
        -Result $doctorResult `
        -AsJson:$Json `
        -StopWasOffered:$OfferStop
}
