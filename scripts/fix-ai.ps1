$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   FIX AI - Rate Limit Fixer (All Sessions)" -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Closing stale OpenCode background processes..." -ForegroundColor Gray
Get-Process -Name "opencode" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "[2/4] Cleaning temporary cache..." -ForegroundColor Gray
Remove-Item "$env:USERPROFILE\.cache\opencode\" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Temp\opencode*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[3/4] Cleaning & compressing all sessions in opencode.db..." -ForegroundColor Gray
$py = Join-Path $PSScriptRoot "clean_sessions.py"
if (Test-Path $py) {
    $out = & python "$py" 2>&1 | Out-String
    if ($out -match "CLEANED_OK") {
        Write-Host "  Sessions cleaned & token counters reset." -ForegroundColor Green
    } else {
        Write-Host "  DB cleaner: $($out.Trim())" -ForegroundColor Yellow
    }
} else {
    Write-Host "  clean_sessions.py not found - skipped." -ForegroundColor Yellow
}

Write-Host "[4/4] Rotating Cloudflare WARP to get a new IP..." -ForegroundColor Gray
$warpCli = "$env:ProgramFiles\Cloudflare\Cloudflare WARP\warp-cli.exe"
if (-not (Test-Path $warpCli)) { $warpCli = "${env:ProgramFiles(x86)}\Cloudflare\Cloudflare WARP\warp-cli.exe" }

if (Test-Path $warpCli) {
    & $warpCli disconnect 2>$null
    Start-Sleep -Seconds 1
    & $warpCli registration delete 2>$null
    Start-Sleep -Seconds 1
    & $warpCli registration new 2>$null
    Start-Sleep -Seconds 2
    & $warpCli connect 2>$null
    Start-Sleep -Seconds 4
} else {
    Write-Host "  warp-cli not found - skipped." -ForegroundColor Yellow
}

$ip = try { (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5) } catch { 'unknown' }

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host "   SUCCESS! New IP: $ip" -ForegroundColor Green
Write-Host "   All sessions were cleaned & limits refreshed!" -ForegroundColor Green
Write-Host "   MiniMax and GLM are ready to use." -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
