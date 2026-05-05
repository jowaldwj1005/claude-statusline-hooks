---
description: Toggle Claude Code Toast-Notifications (global enable/disable, per-event, status)
allowed-tools: Bash
argument-hint: "on | off | status | focus on|off | event <Stop|Notification|SubagentStop> on|off"
---

Run the notification toggle script with the user's arguments and report the result.

Execute:
```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/lib/notify-toggle.ps1" $ARGUMENTS
```

If no argument was passed, show the current status. Print the script's output verbatim.
