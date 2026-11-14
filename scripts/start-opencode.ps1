$ErrorActionPreference = "SilentlyContinue"

# Quick cleanup and session reset so it never starts with rate limit
$py = Join-Path $PSScriptRoot "clean_sessions.py"
if (Test-Path $py) {
    & python "$py" >$null 2>&1
}

Remove-Item "$env:USERPROFILE\.cache\opencode\opencode-service-*.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.local\state\opencode\locks\*" -Recurse -Force -ErrorAction SilentlyContinue

$ip = try { (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5) } catch { 'unknown' }
Write-Host "Current Public IP: $ip" -ForegroundColor Green
Write-Host "Launching OpenCode..." -ForegroundColor Cyan

if ($args.Count -eq 0) {
    & opencode --model "opencode/minimax-m3.1-flash-free"
} else {
    & opencode @args
}
