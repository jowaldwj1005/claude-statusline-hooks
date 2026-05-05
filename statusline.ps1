# Claude Code statusline.
# Output: <branch*dirty+ahead-behind> | <model> | ctx: <used>/<limit> (<pct>%) | cache: <hit>%

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

# --- Token usage + cache hit rate ---
$ctxUsed = 0
$pct = $null
$cacheRead = 0
$cacheCreate = 0

if ($j.context_window.used_percentage -ne $null) {
    $pct = [math]::Round([double]$j.context_window.used_percentage)
}

$cu = $j.context_window.current_usage
if ($cu -and $cu.input_tokens -ne $null) {
    $ctxUsed     = [int]$cu.input_tokens + [int]$cu.cache_read_input_tokens + [int]$cu.cache_creation_input_tokens
    $cacheRead   = [int]$cu.cache_read_input_tokens
    $cacheCreate = [int]$cu.cache_creation_input_tokens
} else {
    # Fallback: parse last "usage" from transcript JSONL
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
                        $ctxUsed     = [int]$u.input_tokens + [int]$u.cache_read_input_tokens + [int]$u.cache_creation_input_tokens
                        $cacheRead   = [int]$u.cache_read_input_tokens
                        $cacheCreate = [int]$u.cache_creation_input_tokens
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

$cacheTotal = $cacheRead + $cacheCreate
$cacheHit = $null
if ($cacheTotal -gt 0) { $cacheHit = [math]::Round(100.0 * $cacheRead / $cacheTotal) }

# --- Git state ---
$cwd = $j.workspace.current_dir
if (-not $cwd) { $cwd = $j.cwd }
$branch = $null
$dirty = 0
$ahead = 0
$behind = 0
if ($cwd -and (Test-Path $cwd)) {
    Push-Location $cwd
    try {
        $branch = (& git --no-optional-locks symbolic-ref --short HEAD 2>$null)
        if ($branch) {
            $statusOut = (& git --no-optional-locks status --porcelain 2>$null)
            if ($statusOut) { $dirty = ($statusOut -split "`n" | Where-Object { $_ -ne '' }).Count }

            $ab = (& git --no-optional-locks rev-list --left-right --count '@{upstream}...HEAD' 2>$null)
            if ($ab -and ($ab -match '^(\d+)\s+(\d+)$')) {
                $behind = [int]$Matches[1]
                $ahead  = [int]$Matches[2]
            }
        }
    } catch {} finally { Pop-Location }
}

# --- Format helpers ---
function Format-Tokens([int]$n) {
    if ($n -ge 1000000) { return ('{0:0.0}M' -f ($n / 1000000.0)) }
    if ($n -ge 1000)    { return ('{0:0}k'   -f ($n / 1000.0)) }
    return "$n"
}

# --- Branch + dirty/ahead/behind (ASCII-only for PS 5.1 encoding-safety) ---
$branchStr = $null
if ($branch) {
    $bits = @($branch)
    if ($dirty  -gt 0) { $bits += "*$dirty" }
    if ($ahead  -gt 0) { $bits += "+$ahead" }
    if ($behind -gt 0) { $bits += "-$behind" }
    $branchStr = ($bits -join ' ')
}

# --- Context string ---
if ($ctxUsed -gt 0) {
    $ctxStr = "ctx: $(Format-Tokens $ctxUsed)/$(Format-Tokens $ctxLimit) ($pct%)"
} else {
    $ctxStr = "ctx: --/$(Format-Tokens $ctxLimit)"
}

# --- Cache string (only if meaningful) ---
$cacheStr = $null
if ($cacheHit -ne $null -and $cacheTotal -gt 1000) { $cacheStr = "cache: $cacheHit%" }

# --- Assemble ---
$parts = @()
if ($branchStr) { $parts += $branchStr }
if ($model)     { $parts += $model }
$parts += $ctxStr
if ($cacheStr)  { $parts += $cacheStr }

[Console]::Out.Write(($parts -join ' | '))
