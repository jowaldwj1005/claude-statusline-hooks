# Claude Code notification dispatcher.
# Wired to multiple hook events (Stop, Notification, SubagentStop) - distinguished
# via the -Event parameter. Reads ~/.claude/notify-config.json for behavior.
#
# Skips toast when:
#   - global "enabled" is false
#   - event-specific "enabled" is false
#   - Stop event but elapsed time < min_duration_sec
#   - skip_when_terminal_focused is true and a terminal is the foreground app
#   - the current session_id is in "disabled_sessions"

param(
    [Parameter(Mandatory)] [ValidateSet('Stop', 'Notification', 'SubagentStop')] [string]$Event
)

$ErrorActionPreference = 'SilentlyContinue'
$payload = [Console]::In.ReadToEnd()

# --- Parse hook payload ---
$session_id = $null
$transcript_path = $null
try {
    $j = $payload | ConvertFrom-Json
    $session_id = $j.session_id
    $transcript_path = $j.transcript_path
} catch {}

# --- Load config ---
$configPath = Join-Path $env:USERPROFILE '.claude\notify-config.json'
if (-not (Test-Path $configPath)) { return }   # no config = silent

$cfg = $null
try { $cfg = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json } catch { return }

if (-not $cfg.enabled) { return }
if ($session_id -and $cfg.disabled_sessions -and ($cfg.disabled_sessions -contains $session_id)) { return }

$evtCfg = $cfg.events.$Event
if (-not $evtCfg -or -not $evtCfg.enabled) { return }

# --- Skip when a terminal/editor is the foreground window ---
function Test-TerminalFocused {
    try {
        Add-Type -Namespace ClaudeNotify -Name U32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(System.IntPtr h, out int p);
'@ -ErrorAction SilentlyContinue
        $hwnd = [ClaudeNotify.U32]::GetForegroundWindow()
        if ($hwnd -eq [IntPtr]::Zero) { return $false }
        $procId = 0
        [void][ClaudeNotify.U32]::GetWindowThreadProcessId($hwnd, [ref]$procId)
        if ($procId -le 0) { return $false }
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $proc) { return $false }
        $terminals = @(
            'WindowsTerminal', 'wt', 'OpenConsole', 'conhost',
            'pwsh', 'powershell', 'cmd',
            'Code', 'Cursor', 'devenv',
            'wezterm-gui', 'alacritty', 'Hyper', 'Tabby', 'Cmder',
            'mintty', 'bash', 'sh', 'zsh'
        )
        return $terminals -contains $proc.ProcessName
    } catch { return $false }
}

if ($cfg.skip_when_terminal_focused -and (Test-TerminalFocused)) { return }

# --- Stop-event min duration filter ---
if ($Event -eq 'Stop' -and $evtCfg.min_duration_sec -gt 0 -and $transcript_path -and (Test-Path $transcript_path)) {
    try {
        $lines = Get-Content -LiteralPath $transcript_path -Tail 200
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            try {
                $obj = $lines[$i] | ConvertFrom-Json
                if ($obj.type -eq 'user' -and $obj.timestamp) {
                    $userTs = [datetime]::Parse($obj.timestamp).ToUniversalTime()
                    $elapsed = ([datetime]::UtcNow - $userTs).TotalSeconds
                    if ($elapsed -lt [double]$evtCfg.min_duration_sec) { return }
                    break
                }
            } catch {}
        }
    } catch {}
}

# --- Compose toast ---
$cwd = $j.cwd
if (-not $cwd) { $cwd = (Get-Location).Path }
$projectName = if ($cwd) { Split-Path -Leaf $cwd } else { 'Claude Code' }

$title = if ($evtCfg.title) { $evtCfg.title } else { 'Claude Code' }
$message = "$projectName"

# --- Toast (WinRT first, balloon fallback) ---
$delivered = $false
try {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
        [Windows.UI.Notifications.ToastTemplateType]::ToastText02
    )
    $xml = [xml]$template.GetXml()
    $xml.toast.visual.binding.text[0].InnerText = $title
    $xml.toast.visual.binding.text[1].InnerText = $message

    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml($xml.OuterXml)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($doc)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Microsoft.PowerShell').Show($toast)
    $delivered = $true
} catch { $delivered = $false }

if (-not $delivered) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $icon = New-Object System.Windows.Forms.NotifyIcon
        $icon.Icon = [System.Drawing.SystemIcons]::Information
        $icon.Visible = $true
        $icon.BalloonTipTitle = $title
        $icon.BalloonTipText  = $message
        $icon.ShowBalloonTip(4000)
        Start-Sleep -Milliseconds 500
        $icon.Dispose()
    } catch {}
}

# --- Sound ---
try {
    $soundName = if ($evtCfg.sound) { $evtCfg.sound } else { 'Asterisk' }
    $sound = [System.Media.SystemSounds]::$soundName
    if ($sound) { $sound.Play() }
} catch {}
