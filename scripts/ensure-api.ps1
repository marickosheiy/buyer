param([int]$Port = 8000)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $projectRoot 'backend\.venv\Scripts\python.exe'
$server = Join-Path $projectRoot 'backend\server.py'
$statePath = Join-Path $projectRoot 'build\lumear-api-process.json'
if (-not (Test-Path -LiteralPath $python)) { throw 'The backend Python environment is missing. Install backend/requirements-mysql.txt first.' }
$checkOutput = & $python $server --storage mysql --check
if ($LASTEXITCODE -ne 0) { throw 'The new MySQL database could not be opened. Check backend/.env.mysql and the MySQL service.' }
$expected = $checkOutput | ConvertFrom-Json
function Read-LumearHealth {
    try { return Invoke-RestMethod "http://127.0.0.1:$Port/api/health" -TimeoutSec 2 } catch { return $null }
}
$health = Read-LumearHealth
if ($health -and $health.application -eq 'lumear_mobile' -and $health.database_tag -eq $expected.database_tag -and $health.code_tag -eq $expected.code_tag) {
    Write-Output 'Lumear MySQL API is ready.'
    exit 0
}
$listening = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($listening) {
    # Only restart a server created by this script in this workspace.
    if (-not (Test-Path -LiteralPath $statePath)) { throw "Port $Port is already occupied. Stop the previous API terminal and try again." }
    $saved = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($saved.pid)" -ErrorAction SilentlyContinue
    if (-not $process -or $process.CommandLine -notlike "*$server*") { throw "Port $Port belongs to another process. Close that process before starting Lumear." }
    # Windows virtualenv Python may launch a child interpreter that owns the socket.
    $ownedListeners = @()
    foreach ($listenerPid in @($listening.OwningProcess | Select-Object -Unique)) {
        $listenerProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $listenerPid" -ErrorAction SilentlyContinue
        if (-not $listenerProcess -or $listenerProcess.CommandLine -notlike "*$server*" -or ($listenerPid -ne $saved.pid -and $listenerProcess.ParentProcessId -ne $saved.pid)) { throw "Port $Port belongs to another process. Close that process before starting Lumear." }
        $ownedListeners += $listenerPid
    }
    foreach ($listenerPid in $ownedListeners) { if ($listenerPid -ne $saved.pid) { Stop-Process -Id $listenerPid } }
    if (Get-Process -Id $saved.pid -ErrorAction SilentlyContinue) {
    Stop-Process -Id $saved.pid
    }
}
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'build') | Out-Null
$apiProcess = Start-Process -FilePath $python -ArgumentList @('"' + $server + '"', '--storage', 'mysql', '--port', $Port) -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $projectRoot 'build\api.stdout.log') -RedirectStandardError (Join-Path $projectRoot 'build\api.stderr.log')
@{pid=$apiProcess.Id;port=$Port} | ConvertTo-Json | Set-Content -LiteralPath $statePath
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    $health = Read-LumearHealth
    if ($health -and $health.application -eq 'lumear_mobile' -and $health.database_tag -eq $expected.database_tag -and $health.code_tag -eq $expected.code_tag) { Write-Output 'Lumear MySQL API started successfully.'; exit 0 }
    if ($apiProcess.HasExited) { throw 'The API exited. Open build/api.stderr.log for the startup error.' }
    Start-Sleep -Milliseconds 250
}
throw 'The API did not become ready. Check build/api.stderr.log.'
