$ErrorActionPreference = 'Stop'
$path = Join-Path (Split-Path -Parent $PSScriptRoot) 'backend\.env.mysql'
$address = (Read-Host 'Gmail address that will send Lumear codes').Trim()
if ($address -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Enter a valid Gmail address.' }
$secure = Read-Host 'Paste the App Password Google generated (hidden while typing)' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $appPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Replace(' ', '')
    if ($appPassword.Length -lt 12 -or $appPassword.Contains("`n") -or $appPassword.Contains("`r")) { throw 'Paste the generated Google App Password, not your normal password.' }
    $values = @{SMTP_HOST='smtp.gmail.com';SMTP_PORT='587';SMTP_USERNAME=$address;SMTP_FROM=$address;SMTP_PASSWORD=$appPassword}
    $lines = [Collections.Generic.List[string]]::new()
    $seen = @{}
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match '^\s*(SMTP_HOST|SMTP_PORT|SMTP_USERNAME|SMTP_FROM|SMTP_PASSWORD)\s*=') {
            $name = $matches[1]
            if (-not $seen[$name]) { $lines.Add($name + '=' + $values[$name]); $seen[$name] = $true }
        } else { $lines.Add($line) }
    }
    foreach ($name in $values.Keys) { if (-not $seen[$name]) { $lines.Add($name + '=' + $values[$name]) } }
    [IO.File]::WriteAllLines($path, $lines, [Text.UTF8Encoding]::new($false))
    Write-Output 'Gmail sender settings saved. The password was not displayed.'
} finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer); $appPassword=$null; $secure.Dispose() }
