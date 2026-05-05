# Claude Code Stop hook — Windows toast notification.
# Fires when Claude finishes a response. Reads the Stop-hook JSON from stdin
# (we don't need it, but consume it so the pipe closes cleanly).

$ErrorActionPreference = 'SilentlyContinue'
$null = [Console]::In.ReadToEnd()

$cwd = (Get-Location).Path
$projectName = Split-Path -Leaf $cwd
$title = "Claude Code"
$message = "$projectName ist fertig"

# --- Try modern Windows 10/11 toast via WinRT (no external deps) ---
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
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(
        "Microsoft.PowerShell"
    ).Show($toast)
    $delivered = $true
} catch {
    $delivered = $false
}

# --- Fallback: System tray balloon (works on every Windows) ---
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

# --- Subtle audio cue ---
try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
