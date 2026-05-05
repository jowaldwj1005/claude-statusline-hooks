# Claude Code Windows Setup - Bootstrap (v2)
#
# Online one-liner:
#   iwr https://raw.githubusercontent.com/jowaldwj1005/claude-statusline-hooks/main/install.ps1 | iex
#
# Local clone:
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

param(
    [string]$Repo   = 'jowaldwj1005/claude-statusline-hooks',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'

$claudeDir   = Join-Path $env:USERPROFILE '.claude'
$hooksDir    = Join-Path $claudeDir 'hooks'
$libDir      = Join-Path $claudeDir 'lib'
$cmdDir      = Join-Path $claudeDir 'commands'
$settings    = Join-Path $claudeDir 'settings.json'
$notifyCfg   = Join-Path $claudeDir 'notify-config.json'

$statusPs1   = Join-Path $claudeDir 'statusline.ps1'
$notifyPs1   = Join-Path $hooksDir  'notify.ps1'
$togglePs1   = Join-Path $libDir    'notify-toggle.ps1'
$cmdMd       = Join-Path $cmdDir    'notify.md'

Write-Host "-> Target: $claudeDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $claudeDir, $hooksDir, $libDir, $cmdDir | Out-Null

# --- 1. Fetch files ---
$scriptRoot = $PSScriptRoot
$srcLocal = $scriptRoot -and (Test-Path (Join-Path $scriptRoot 'statusline.ps1'))

function Get-File($relative, $dest) {
    if ($srcLocal) {
        Copy-Item -Force (Join-Path $scriptRoot $relative) $dest
        Write-Host "  copied $relative" -ForegroundColor DarkGray
    } else {
        $url = "https://raw.githubusercontent.com/$Repo/$Branch/$relative"
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Host "  downloaded $relative" -ForegroundColor DarkGray
    }
}

Write-Host "-> Installing scripts..." -ForegroundColor Cyan
Get-File 'statusline.ps1'             $statusPs1
Get-File 'hooks/notify.ps1'           $notifyPs1
Get-File 'lib/notify-toggle.ps1'      $togglePs1
Get-File 'commands/notify.md'         $cmdMd

# Default notify-config.json - only on first install (don't clobber user changes)
if (-not (Test-Path $notifyCfg)) {
    Get-File 'notify-config.default.json' $notifyCfg
} else {
    Write-Host "  kept existing notify-config.json" -ForegroundColor DarkGray
}

# Cleanup: remove obsolete v1 file if present
$obsolete = Join-Path $hooksDir 'notify-on-stop.ps1'
if (Test-Path $obsolete) {
    Remove-Item -Force $obsolete
    Write-Host "  removed obsolete notify-on-stop.ps1" -ForegroundColor DarkGray
}

# --- 2. Patch settings.json ---
Write-Host "-> Patching settings.json..." -ForegroundColor Cyan

if (Test-Path $settings) {
    $cfg = Get-Content -Raw -LiteralPath $settings | ConvertFrom-Json
} else {
    $cfg = New-Object PSObject
}

$ps = 'powershell -NoProfile -ExecutionPolicy Bypass -File'
$statusLineCmd      = "$ps `"$statusPs1`""
$notifyStopCmd      = "$ps `"$notifyPs1`" -Event Stop"
$notifyNotifyCmd    = "$ps `"$notifyPs1`" -Event Notification"
$notifySubagentCmd  = "$ps `"$notifyPs1`" -Event SubagentStop"

# statusLine - replace wholesale
$cfg | Add-Member -MemberType NoteProperty -Name 'statusLine' -Force -Value ([PSCustomObject]@{
    type    = 'command'
    command = $statusLineCmd
})

# hooks - preserve other event types, replace ours where ours points at notify.ps1
$hooks = $cfg.hooks
if (-not $hooks) { $hooks = New-Object PSObject }

function Set-OurHook($eventName, $command) {
    $existing = $hooks.$eventName
    $newEntries = @()
    if ($existing) {
        foreach ($entry in @($existing)) {
            $isOurs = $false
            foreach ($h in @($entry.hooks)) {
                if ($h.command -match 'notify(-on-stop)?\.ps1') { $isOurs = $true }
            }
            if (-not $isOurs) { $newEntries += $entry }
        }
    }
    $newEntries += [PSCustomObject]@{
        matcher = ''
        hooks   = @([PSCustomObject]@{ type = 'command'; command = $command })
    }
    $hooks | Add-Member -MemberType NoteProperty -Name $eventName -Force -Value $newEntries
}

Set-OurHook 'Stop'         $notifyStopCmd
Set-OurHook 'Notification' $notifyNotifyCmd
Set-OurHook 'SubagentStop' $notifySubagentCmd

$cfg | Add-Member -MemberType NoteProperty -Name 'hooks' -Force -Value $hooks

# --- 3. Write back ---
$cfg | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settings -Encoding UTF8

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Restart Claude Code to pick up the new statusline + hooks." -ForegroundColor Yellow
Write-Host ""
Write-Host "Use /notify to toggle: /notify on|off|status|focus on|off|event Stop on|off" -ForegroundColor Cyan
