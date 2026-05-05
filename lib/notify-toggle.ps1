# Toggle/inspect Claude Code notification config.
# Called by the /notify slash command (and runnable standalone).
#
# Usage:
#   notify-toggle.ps1 on              # global enable
#   notify-toggle.ps1 off             # global disable
#   notify-toggle.ps1 status          # print current config
#   notify-toggle.ps1 event Stop on   # enable a specific event
#   notify-toggle.ps1 event Stop off  # disable a specific event
#   notify-toggle.ps1 focus on|off    # toggle skip_when_terminal_focused

param([Parameter(ValueFromRemainingArguments)] [string[]]$ArgList)

$ErrorActionPreference = 'Stop'
$cfgPath = Join-Path $env:USERPROFILE '.claude\notify-config.json'

if (-not (Test-Path $cfgPath)) {
    Write-Host "No config at $cfgPath - run install.ps1 first." -ForegroundColor Yellow
    return
}

$cfg = Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json

if (-not $ArgList -or $ArgList.Count -eq 0) { $ArgList = @('status') }
$cmd = $ArgList[0].ToLower()

switch ($cmd) {
    'on'     { $cfg.enabled = $true;  Write-Host "Notifications: ON"  -ForegroundColor Green }
    'off'    { $cfg.enabled = $false; Write-Host "Notifications: OFF" -ForegroundColor Yellow }
    'focus'  {
        $val = if ($ArgList.Count -gt 1 -and $ArgList[1] -eq 'off') { $false } else { $true }
        $cfg | Add-Member -MemberType NoteProperty -Name 'skip_when_terminal_focused' -Force -Value $val
        Write-Host "skip_when_terminal_focused: $val" -ForegroundColor Cyan
    }
    'event'  {
        if ($ArgList.Count -lt 3) { Write-Host "usage: event <Stop|Notification|SubagentStop> <on|off>" -ForegroundColor Red; return }
        $evt = $ArgList[1]; $val = ($ArgList[2] -eq 'on')
        if (-not $cfg.events.$evt) { Write-Host "unknown event: $evt" -ForegroundColor Red; return }
        $cfg.events.$evt.enabled = $val
        Write-Host "$evt event: $(if($val){'ON'}else{'OFF'})" -ForegroundColor Cyan
    }
    'status' {
        Write-Host ""
        Write-Host "Global enabled       : $($cfg.enabled)" -ForegroundColor Cyan
        Write-Host "Skip if terminal foc.: $($cfg.skip_when_terminal_focused)" -ForegroundColor Cyan
        foreach ($e in $cfg.events.PSObject.Properties.Name) {
            $en = $cfg.events.$e.enabled
            $extra = ''
            if ($e -eq 'Stop' -and $cfg.events.Stop.min_duration_sec) { $extra = " (min $($cfg.events.Stop.min_duration_sec)s)" }
            Write-Host ("  {0,-15} : {1}{2}" -f $e, $(if($en){'ON'}else{'OFF'}), $extra)
        }
        Write-Host ""
        return
    }
    default  { Write-Host "unknown: $cmd  (try: on|off|status|focus|event)" -ForegroundColor Red; return }
}

$cfg | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $cfgPath -Encoding UTF8
