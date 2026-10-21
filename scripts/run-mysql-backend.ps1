$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendPython = Join-Path $projectRoot 'backend\.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $backendPython)) {
    throw 'Create backend/.venv and install backend/requirements-mysql.txt first. See backend/README.md.'
}
Push-Location $projectRoot
try {
    & $backendPython backend/server.py --storage mysql --check
    if ($LASTEXITCODE -ne 0) { throw 'MySQL check failed. Check backend/.env.mysql and your MySQL service.' }
    & $backendPython backend/server.py --storage mysql
} finally { Pop-Location }
