# Claude Code statusline
# Reads JSON from stdin, prints: <branch> | <model> | ctx: <used>/<limit> (<pct>%)

$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()

try { $j = $raw | ConvertFrom-Json } catch { $j = $null }

# --- Model ---
$model = if ($j -and $j.model.display_name) { $j.model.display_name } else { 'unknown' }

# --- Context limit ---
if ($model -match '1M') {
    $ctxLimit = 1000000
} elseif ($j.context_window.context_window_size) {
    $ctxLimit = [int]$j.context_window.context_window_size
} else {
    $ctxLimit = 200000
}

# --- Token usage ---
$ctxUsed = 0
$pct = $null

if ($j.context_window.used_percentage -ne $null) {
    $pct = [math]::Round([double]$j.context_window.used_percentage)
}

$cu = $j.context_window.current_usage
if ($cu -and $cu.input_tokens -ne $null) {
    $ctxUsed = [int]$cu.input_tokens + [int]$cu.cache_read_input_tokens + [int]$cu.cache_creation_input_tokens
} else {
    # Fallback: parse last "usage" object from transcript JSONL
    $tp = $j.transcript_path
    if ($tp -and (Test-Path $tp)) {
        $lines = Get-Content -LiteralPath $tp -Tail 200 -ErrorAction SilentlyContinue
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -match '"usage"\s*:\s*\{') {
                try {
                    $obj = $lines[$i] | ConvertFrom-Json
                    $u = $obj.message.usage
                    if (-not $u) { $u = $obj.usage }
                    if ($u) {
                        $ctxUsed = [int]$u.input_tokens + [int]$u.cache_read_input_tokens + [int]$u.cache_creation_input_tokens
                        break
                    }
                } catch {}
            }
        }
    }
}

if ($ctxUsed -gt 0 -and $pct -eq $null) {
    $pct = [math]::Round($ctxUsed * 100.0 / $ctxLimit)
}

# --- Git branch ---
$cwd = $j.workspace.current_dir
if (-not $cwd) { $cwd = $j.cwd }
$branch = $null
if ($cwd -and (Test-Path $cwd)) {
    try {
        Push-Location $cwd
        $branch = (& git --no-optional-locks symbolic-ref --short HEAD 2>$null)
    } catch {} finally { Pop-Location }
}

# --- Format ---
function Format-Tokens([int]$n) {
    if ($n -ge 1000000) { return ('{0:0.0}M' -f ($n / 1000000.0)) }
    if ($n -ge 1000)    { return ('{0:0}k'   -f ($n / 1000.0)) }
    return "$n"
}

if ($ctxUsed -gt 0) {
    $usedFmt  = Format-Tokens $ctxUsed
    $limitFmt = Format-Tokens $ctxLimit
    $ctxStr = "ctx: $usedFmt/$limitFmt ($pct%)"
} else {
    $limitFmt = Format-Tokens $ctxLimit
    $ctxStr = "ctx: --/$limitFmt"
}

$parts = @()
if ($branch) { $parts += $branch }
if ($model)  { $parts += $model }
$parts += $ctxStr

[Console]::Out.Write(($parts -join ' | '))
