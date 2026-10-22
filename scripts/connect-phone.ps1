param([string]$DeviceId = '')
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'ensure-api.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'The API did not start.' }
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbPath)) { throw 'Android platform-tools were not found.' }
if (-not $DeviceId) {
    $devices = @(& $adbPath devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    if ($devices.Count -ne 1) { throw 'Connect exactly one Android device, or pass -DeviceId with its serial number.' }
    $DeviceId = $devices[0]
}
& $adbPath -s $DeviceId reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -ne 0) { throw 'Approve USB debugging on the device and reconnect it.' }
Write-Output 'Device connected to the Lumear API.'
