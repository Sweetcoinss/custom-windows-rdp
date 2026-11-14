$warpCli = "$env:ProgramFiles\Cloudflare\Cloudflare WARP\warp-cli.exe"
if (-not (Test-Path $warpCli)) { $warpCli = "${env:ProgramFiles(x86)}\Cloudflare\Cloudflare WARP\warp-cli.exe" }

Remove-Item "$env:USERPROFILE\.cache\opencode\" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Temp\opencode*" -Recurse -Force -ErrorAction SilentlyContinue

$ip = try { (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5) } catch { 'unknown' }
Write-Host "Current Public IP: $ip" -ForegroundColor Green
Write-Host "Launching OpenCode..." -ForegroundColor Cyan

& opencode @args
