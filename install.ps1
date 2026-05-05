# Claude Code Windows Setup — Bootstrap
# Installs the statusline + Stop-notification hook into ~/.claude on this machine.
#
# Usage (online one-liner):
#   iwr https://raw.githubusercontent.com/jowaldwj1005/claude-code-windows-setup/main/install.ps1 | iex
#
# Usage (local clone):
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

param(
    [string]$Repo   = 'jowaldwj1005/claude-code-windows-setup',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$hooksDir  = Join-Path $claudeDir 'hooks'
$settings  = Join-Path $claudeDir 'settings.json'
$statusPs1 = Join-Path $claudeDir 'statusline.ps1'
$notifyPs1 = Join-Path $hooksDir  'notify-on-stop.ps1'

Write-Host "→ Target: $claudeDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $claudeDir, $hooksDir | Out-Null

# --- 1. Fetch script files ---
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

Write-Host "→ Installing scripts..." -ForegroundColor Cyan
Get-File 'statusline.ps1'             $statusPs1
Get-File 'hooks/notify-on-stop.ps1'   $notifyPs1

# --- 2. Patch settings.json (merge, never clobber) ---
Write-Host "→ Patching settings.json..." -ForegroundColor Cyan

if (Test-Path $settings) {
    $json = Get-Content -Raw -LiteralPath $settings
    $cfg  = $json | ConvertFrom-Json
} else {
    $cfg = New-Object PSObject
}

$statusLineCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $statusPs1 + '"'
$notifyCmd     = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $notifyPs1 + '"'

# statusLine — replace wholesale
$cfg | Add-Member -MemberType NoteProperty -Name 'statusLine' -Force -Value ([PSCustomObject]@{
    type    = 'command'
    command = $statusLineCmd
})

# hooks.Stop — append our hook if not already present, preserve other hook events
$hooks = $cfg.hooks
if (-not $hooks) { $hooks = New-Object PSObject }

$stopHook = [PSCustomObject]@{
    matcher = ''
    hooks   = @(
        [PSCustomObject]@{ type = 'command'; command = $notifyCmd }
    )
}

$existingStop = $hooks.Stop
$hasOurs = $false
if ($existingStop) {
    foreach ($entry in $existingStop) {
        foreach ($h in @($entry.hooks)) {
            if ($h.command -like '*notify-on-stop.ps1*') { $hasOurs = $true }
        }
    }
}

if ($hasOurs) {
    Write-Host '  Stop hook already present — skipping' -ForegroundColor DarkGray
} else {
    $newStop = @()
    if ($existingStop) { $newStop = @($existingStop) }
    $newStop += $stopHook
    $hooks | Add-Member -MemberType NoteProperty -Name 'Stop' -Force -Value $newStop
}
$cfg | Add-Member -MemberType NoteProperty -Name 'hooks' -Force -Value $hooks

# --- 3. Write back ---
$out = $cfg | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $settings -Value $out -Encoding UTF8

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Restart Claude Code to pick up the new statusline and hook." -ForegroundColor Yellow
