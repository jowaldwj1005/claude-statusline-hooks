# claude-code-windows-setup

Persönliche Claude-Code-Konfiguration für Windows: Statusline mit Kontextfenster-Auslastung + Stop-Hook mit Toast-Notification.

## Was ist drin?

- **`statusline.ps1`** — Statusline unten im Terminal mit `<branch> | <model> | ctx: <used>/<limit> (<pct>%)`. Erkennt automatisch das 1M-Kontextfenster bei Opus-Varianten.
- **`hooks/notify-on-stop.ps1`** — Stop-Hook, der eine Windows-Toast-Notification + Sound feuert, wenn Claude eine Antwort fertig hat. Praktisch wenn man nebenher arbeitet.
- **`install.ps1`** — Bootstrap, der beides nach `~/.claude` kopiert und `settings.json` patcht (merget, ohne Bestehendes zu überschreiben).

## Voraussetzungen

- Windows 10/11
- Claude Code CLI installiert
- PowerShell 5.1+ (kommt mit Windows)
- Keine externen Module nötig — Toasts laufen über die Windows-WinRT-API mit Fallback auf System-Tray-Balloon

## Installation

### One-Liner (empfohlen)

```powershell
iwr https://raw.githubusercontent.com/jowaldwj1005/claude-code-windows-setup/main/install.ps1 | iex
```

### Lokaler Clone

```powershell
git clone https://github.com/jowaldwj1005/claude-code-windows-setup.git
cd claude-code-windows-setup
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

Danach Claude Code einmal beenden und neu starten (`/exit`), damit Statusline und Hook geladen werden.

## Was macht `install.ps1`?

1. Legt `~/.claude/` und `~/.claude/hooks/` an (falls nicht vorhanden)
2. Lädt die beiden PS1-Skripte (lokal kopieren oder von GitHub Raw)
3. Patcht `~/.claude/settings.json`:
   - Setzt/ersetzt den `statusLine`-Block
   - Hängt unseren Stop-Hook an `hooks.Stop` an (überschreibt keine anderen Hooks)
4. Bestehende `permissions`, `enabledPlugins` etc. bleiben unangetastet

## Statusline anpassen

Format ändern? Direkt `~/.claude/statusline.ps1` editieren — die JSON-Felder die Claude Code liefert sind dokumentiert unter <https://code.claude.com/docs/en/statusline>.

## Notification anpassen

Im `notify-on-stop.ps1` kannst du `$message`, den Sound (`SystemSounds.Asterisk`) oder die Anzeigedauer (`ShowBalloonTip(4000)`) ändern.

## Lizenz

MIT — nutze, forke, passe an.
