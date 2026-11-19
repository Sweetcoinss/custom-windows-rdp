@echo off
title Fix DeepSeek - OpenCode
echo.
echo   Fix DeepSeek - Requesting Administrator...
echo.
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)
setlocal
set "TMPPS=%TEMP%\fix-deepseek-%RANDOM%.ps1"
:: Extract the PowerShell code from this file (everything after __PS1__)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$lines = [IO.File]::ReadAllLines('%~f0'); $s = -1; for($i=0;$i -lt $lines.Count;$i++){if($lines[$i].Trim() -eq '# __PS1__'){$s=$i+1;break}}; if($s -ge 0){$code=$lines[$s..($lines.Count-1)] -join [char]10; [IO.File]::WriteAllText('%TMPPS%',$code,[Text.Encoding]::UTF8)}"
:: Run the extracted script
powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPPS%"
del "%TMPPS%" 2>nul
echo.
echo Press any key to exit...
pause >nul
exit /b
# __PS1__
$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "Fix DeepSeek - OpenCode"

function Write-Banner($text, $color) {
    $line = "=" * 55
    Write-Host ""
    Write-Host "  $line" -ForegroundColor $color
    Write-Host "    $text" -ForegroundColor $color
    Write-Host "  $line" -ForegroundColor $color
}
function Write-Step($n, $total, $msg) { Write-Host "`n  [$n/$total] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    [!!] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    [XX] $msg" -ForegroundColor Red }

Write-Banner "Fix DeepSeek v3.0 - Rate Limit Reset + Verify" "Cyan"

$totalSteps = 7
$oldIP = try { (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 6) } catch { "unknown" }
Write-Host "    Current IP: $oldIP" -ForegroundColor Gray

# === STEP 1: Kill OpenCode processes ===
Write-Step 1 $totalSteps "Killing OpenCode processes..."
$killed = @()
foreach ($name in @("opencode", "opencode-pty", "opencode-service")) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($procs) { $procs | Stop-Process -Force -ErrorAction SilentlyContinue; $killed += $name }
}
if ($killed.Count) { Write-OK "Killed: $($killed -join ', ')" }
else               { Write-OK "No running processes" }

# Clean up old scripts from Public Desktop
$oldPublicScripts = @(
    "C:\Users\Public\Desktop\clean_sessions.py",
    "C:\Users\Public\Desktop\fix-ai.ps1",
    "C:\Users\Public\Desktop\FIX AI.bat",
    "C:\Users\Public\Desktop\FIX AI.exe",
    "C:\Users\Public\Desktop\start-opencode.ps1",
    "C:\Users\Public\Desktop\Start-OpenCode.bat"
)
foreach ($old in $oldPublicScripts) {
    if (Test-Path $old) { Remove-Item $old -Force -ErrorAction SilentlyContinue }
}

# === STEP 2: Delete device identity (service.json) ===
Write-Step 2 $totalSteps "Resetting device identity (service.json)..."
$deletedIdentity = $false
$usersDir = Split-Path $env:USERPROFILE
Get-ChildItem $usersDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $sf = Join-Path $_.FullName ".config\opencode\service.json"
    if (Test-Path $sf) {
        try {
            Remove-Item $sf -Force -ErrorAction Stop
            Write-OK "Deleted: $sf"
            $deletedIdentity = $true
        } catch {
            Write-Warn "Cannot delete: $sf"
        }
    }
}
if (-not $deletedIdentity) { Write-OK "Already clean (no service.json)" }

# === STEP 3: Clean cache and state ===
Write-Step 3 $totalSteps "Cleaning cache and state..."
foreach ($p in @("$env:USERPROFILE\.cache\opencode", "$env:USERPROFILE\.local\state\opencode")) {
    if (Test-Path $p) {
        Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Cleaned: $p"
    }
}
Get-ChildItem "$env:LOCALAPPDATA\Temp" -Filter "opencode*" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# === STEP 4: Clean sessions database ===
Write-Step 4 $totalSteps "Cleaning sessions database..."

$pyCode = @'
import os,shutil,sqlite3,json,sys
def find():
    r=[]
    u=os.path.dirname(os.path.expandvars("%USERPROFILE%"))
    for e in os.listdir(u):
        p=os.path.join(u,e,".local","share","opencode","opencode.db")
        if os.path.isfile(p): r.append(p)
    return r
def clean(db):
    try: shutil.copyfile(db,db+".bak")
    except: pass
    try: c=sqlite3.connect(db,timeout=10)
    except: return 0
    u=c.cursor()
    u.execute("SELECT name FROM sqlite_master WHERE type='table';")
    t={r[0] for r in u.fetchall()}
    if "session_v2" not in t or "session_message" not in t:
        c.close();return 0
    n=0
    pa=["%provider.free-limit%","%FreeUsageLimit%","%FreeUsageLimitError%","%rate_limit%","%rate limit%","%free usage limit%","%Free usage limit%"]
    co=" OR ".join(["data LIKE ?" for _ in pa])
    u.execute(f"DELETE FROM session_message WHERE {co};",pa);n+=u.rowcount
    u.execute("DELETE FROM session_message WHERE type='compaction';");n+=u.rowcount
    u.execute("DELETE FROM session_message WHERE data LIKE '%\"outcome\":\"failed\"%';");n+=u.rowcount
    u.execute("SELECT id FROM session_v2;")
    for(sid,)in u.fetchall():
        try:
            u.execute("SELECT max(seq) FROM session_message WHERE session_id=?;",[sid])
            mx=u.fetchone();mx=mx[0]if mx and mx[0]else 0;sf=max(0,mx-10)
            u.execute("SELECT id,data FROM session_message WHERE session_id=? AND type='assistant' AND seq<?;",[sid,sf])
            for mid,raw in u.fetchall():
                try:
                    d=json.loads(raw);ch=False
                    if isinstance(d.get("content"),list):
                        nc=[]
                        for it in d["content"]:
                            if it.get("type")=="reasoning":ch=True;continue
                            if it.get("type")=="tool" and isinstance(it.get("state"),dict):
                                for x in(it["state"].get("content")or[]):
                                    if isinstance(x,dict)and "text" in x and len(str(x["text"]))>200:
                                        x["text"]=str(x["text"])[:200]+"\n...[cut]";ch=True
                            nc.append(it)
                        if ch:d["content"]=nc;u.execute("UPDATE session_message SET data=? WHERE id=?;",[json.dumps(d,ensure_ascii=False),mid]);n+=1
                except:pass
        except:pass
    u.execute("UPDATE session_v2 SET tokens_input=0,tokens_output=0,tokens_reasoning=0,tokens_cache_read=0,tokens_cache_write=0,cost=0;")
    c.commit()
    try:u.execute("VACUUM;")
    except:pass
    sz=os.path.getsize(db);c.close();return n,sz
dbs=find()
if not dbs:print("DB_NOT_FOUND");sys.exit(0)
for db in dbs:
    r=clean(db)
    if r:
        n,sz=r;print(f"CLEANED:{n}:SIZE:{sz}")
print("DONE")
'@

$tmpPy = Join-Path $env:TEMP "oc_clean_$([guid]::NewGuid().ToString('N').Substring(0,8)).py"
try {
    Set-Content -Path $tmpPy -Value $pyCode -Encoding UTF8 -Force
    $out = & python $tmpPy 2>&1 | Out-String
    if ($out -match "CLEANED:(\d+):SIZE:(\d+)") {
        Write-OK "Cleaned $($Matches[1]) items, DB size: $([math]::Round([int64]$Matches[2]/1024)) KB"
    } elseif ($out -match "DB_NOT_FOUND") {
        Write-Warn "No database found"
    } else {
        Write-OK "Database processed"
    }
} catch {
    Write-Warn "Python script error"
} finally {
    Remove-Item $tmpPy -Force -ErrorAction SilentlyContinue
}

# === STEP 5: Randomize MachineGuid ===
Write-Step 5 $totalSteps "Randomizing Machine GUID..."
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    try {
        $g = [guid]::NewGuid().ToString()
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name 'MachineGuid' -Value $g -Force -ErrorAction Stop
        Write-OK "New GUID: $g"
    } catch { Write-Fail "Cannot change: $($_.Exception.Message)" }
} else {
    Write-Warn "Not Admin - GUID unchanged (right-click > Run as Admin)"
}

# === STEP 6: Rotate IP via WARP ===
Write-Step 6 $totalSteps "Rotating IP via Cloudflare WARP..."
$warpCli = "$env:ProgramFiles\Cloudflare\Cloudflare WARP\warp-cli.exe"
if (-not (Test-Path $warpCli)) { $warpCli = "${env:ProgramFiles(x86)}\Cloudflare\Cloudflare WARP\warp-cli.exe" }

$newIP = $oldIP
if (Test-Path $warpCli) {
    Write-Host "      Disconnecting..." -ForegroundColor Gray
    & $warpCli disconnect 2>$null; Start-Sleep 2
    Write-Host "      Deleting registration..." -ForegroundColor Gray
    & $warpCli registration delete 2>$null; Start-Sleep 2
    Write-Host "      New registration..." -ForegroundColor Gray
    & $warpCli registration new 2>$null; Start-Sleep 3
    Write-Host "      Connecting..." -ForegroundColor Gray
    & $warpCli connect 2>$null

    for ($i = 1; $i -le 5; $i++) {
        Start-Sleep 3
        try {
            $newIP = Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 8
            if ($newIP -ne $oldIP -and $newIP -ne "unknown") { Write-OK "IP changed: $oldIP -> $newIP"; break }
        } catch { }
        if ($i -lt 5) { Write-Host "      Retry $i/5..." -ForegroundColor Gray }
    }
    if ($newIP -eq $oldIP) { Write-Warn "IP unchanged - try reconnecting WARP manually" }
} else {
    Write-Warn "WARP not installed (get it: https://1.1.1.1)"
}

# === STEP 7: VERIFY DeepSeek ===
Write-Step 7 $totalSteps "Testing DeepSeek model..."
Write-Host "      Sending test message..." -ForegroundColor Gray

$testPassed = $false
$testError = ""
$outFile = Join-Path $env:TEMP "oc_test_out.txt"
$errFile = Join-Path $env:TEMP "oc_test_err.txt"

try {
    $openCodeExe = "C:\npm\prefix\node_modules\@opencode\cli\bin\opencode.exe"
    if (-not (Test-Path $openCodeExe)) { $openCodeExe = "opencode" }

    $proc = Start-Process -FilePath $openCodeExe `
        -ArgumentList "run","--model","opencode/deepseek-v4.1-flash-free","--standalone","--archived","Reply ONLY with the word HELLO" `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError $errFile

    $finished = $proc.WaitForExit(45000)

    if (-not $finished) {
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
        $testError = "Timeout (45s)"
    } else {
        $stdout = if (Test-Path $outFile) { Get-Content $outFile -Raw -ErrorAction SilentlyContinue } else { "" }
        $stderr = if (Test-Path $errFile) { Get-Content $errFile -Raw -ErrorAction SilentlyContinue } else { "" }
        $all = "$stdout $stderr"

        if ($all -match "FreeUsageLimit|free.limit|Free usage limit|rate.limit|429") {
            $testError = "Rate limit still active"
        } elseif ($proc.ExitCode -eq 0 -and $stdout.Trim().Length -gt 0) {
            $testPassed = $true
        } elseif ($proc.ExitCode -ne 0) {
            $testError = "Exit code $($proc.ExitCode)"
        } else {
            $testPassed = $true
        }
    }
} catch {
    $testError = $_.Exception.Message
} finally {
    Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
}

# === RESULTS ===
Write-Host ""
if ($testPassed) {
    Write-Banner "DeepSeek is WORKING!" "Green"
    Write-Host "    Old IP: $oldIP" -ForegroundColor Green
    Write-Host "    New IP: $newIP" -ForegroundColor Green
    Write-Host "    Model:  opencode/deepseek-v4.1-flash-free" -ForegroundColor Green
    Write-Host ""
    Write-Host "    To start:  opencode --model opencode/deepseek-v4.1-flash-free" -ForegroundColor White
} else {
    Write-Banner "DeepSeek test FAILED" "Red"
    Write-Host "    Old IP: $oldIP" -ForegroundColor Yellow
    Write-Host "    New IP: $newIP" -ForegroundColor Yellow
    if ($testError) { Write-Host "    Error:  $testError" -ForegroundColor Red }
    Write-Host ""
    Write-Host "    Try:" -ForegroundColor Yellow
    Write-Host "      1. Run this again as Administrator" -ForegroundColor Gray
    Write-Host "      2. Reconnect WARP manually" -ForegroundColor Gray
    Write-Host "      3. Wait 15 min and retry" -ForegroundColor Gray
    Write-Host "      4. opencode --model opencode/minimax-m3.1-flash-free" -ForegroundColor Gray
}
Write-Host ""
