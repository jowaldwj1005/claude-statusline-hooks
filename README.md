# claude-statusline-hooks

Persönliche Claude-Code-Konfiguration für Windows: Statusline mit Git/Token-Infos + smarte, customizable Notifications.

## Features

### Statusline

```
main *3 ↑1 | Claude Opus 4.7 (1M context) | ctx: 280k/1M (28%) | cache: 87%
```

- **Branch + dirty count** — `*3` = 3 uncommitted Files
- **Ahead/behind** — `↑1 ↓2` vs upstream
- **Modell-Name + Kontextfenster** — erkennt 1M-Varianten automatisch
- **Cache-Hit-Rate** — sichtbar wenn Cache spürbar genutzt wird (>1k Tokens)

### Smarte Notifications

- **Hook-basiert** — feuert auf `Stop`, `Notification` (Permission-Prompts!), optional `SubagentStop`
- **Foreground-Aware** — keine Toasts wenn dein Terminal/Editor im Vordergrund ist (löst das "Toast kommt obwohl ich vor dem Fenster sitze"-Problem)
- **Min-Duration-Filter** — `Stop`-Toast nur wenn die Antwort > N Sekunden gedauert hat (default 10s)
- **Pro-Event-Konfig** — Title, Sound, On/Off pro Event
- **Slash-Command** — `/notify` zum Live-Toggeln, ohne Restart

## Voraussetzungen

- Windows 10/11
- Claude Code CLI
- PowerShell 5.1+ (mit Windows ausgeliefert)
- Keine externen Module — Toasts via WinRT-API mit System-Tray-Balloon-Fallback

## Installation

### One-Liner

```powershell
iwr https://raw.githubusercontent.com/jowaldwj1005/claude-statusline-hooks/main/install.ps1 | iex
```

### Lokaler Clone

```powershell
git clone https://github.com/jowaldwj1005/claude-statusline-hooks.git
cd claude-statusline-hooks
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

Danach Claude Code beenden und neu starten.

## Slash-Command `/notify`

Live-Steuerung der Notifications, ohne `settings.json` zu editieren:

| Befehl | Wirkung |
|---|---|
| `/notify status` | Aktuelle Konfiguration anzeigen |
| `/notify on` | Notifications global einschalten |
| `/notify off` | Notifications global ausschalten |
| `/notify focus on` | Foreground-Window-Detection einschalten (default) |
| `/notify focus off` | Toasts auch wenn Fenster aktiv ist |
| `/notify event Stop off` | Nur das `Stop`-Event ausschalten |
| `/notify event Notification on` | Permission-Prompt-Toasts einschalten |
| `/notify event SubagentStop on` | Subagent-Fertig-Toasts aktivieren |

## Konfiguration

Default-Config landet bei der Erstinstallation unter `~/.claude/notify-config.json`:

```json
{
  "enabled": true,
  "skip_when_terminal_focused": true,
  "events": {
    "Stop":         { "enabled": true, "min_duration_sec": 10, "title": "Claude fertig",       "sound": "Asterisk" },
    "Notification": { "enabled": true,                          "title": "Claude wartet auf dich", "sound": "Exclamation" },
    "SubagentStop": { "enabled": false,                         "title": "Subagent fertig",   "sound": "Asterisk" }
  }
}
```

Bei späteren `install.ps1`-Läufen wird diese Datei nicht überschrieben.

## Architektur

```
~/.claude/
├── settings.json              ← gepatched: statusLine + 3 hook-events
├── statusline.ps1             ← Statusline-Renderer
├── notify-config.json         ← Notification-Verhalten (vom User editierbar)
├── hooks/
│   └── notify.ps1             ← Hook-Dispatcher (Event-typ via -Event Param)
├── lib/
│   └── notify-toggle.ps1      ← Wird von /notify aufgerufen
└── commands/
    └── notify.md              ← Slash-Command-Definition
```

Ein Dispatcher-Skript für alle Events, weil sich Logik wie Foreground-Detection und Config-Lookup sonst dreimal duplizieren würde.

## Lizenz

MIT
