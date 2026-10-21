$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$caPath = Join-Path $projectRoot 'backend\aiven-ca.pem'
if (-not (Test-Path -LiteralPath $caPath)) { throw 'Download the Aiven CA certificate and save it as C:\LumearBuyer\backend\aiven-ca.pem first.' }
$secretUri = Read-Host 'Paste the Service URI from Aiven (hidden while typing)' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretUri)
try {
    $uri = [Uri][Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ($uri.Scheme -ne 'mysql' -or -not $uri.Host -or $uri.UserInfo -notmatch ':') { throw 'Use the MySQL Service URI from the Aiven overview page.' }
    $credentials = $uri.UserInfo.Split(':',2)
    $database = $uri.AbsolutePath.Trim('/')
    if (-not $database) { throw 'The Service URI must include the database name.' }
    $lines = @(
        'MYSQL_HOST=' + $uri.DnsSafeHost
        'MYSQL_PORT=' + $uri.Port
        'MYSQL_DATABASE=' + $database
        'MYSQL_USER=' + [Uri]::UnescapeDataString($credentials[0])
        'MYSQL_PASSWORD=' + [Uri]::UnescapeDataString($credentials[1])
        'MYSQL_SSL_REQUIRED=true'
        'MYSQL_SSL_CA=' + $caPath
        'PRIVATE_UPLOAD_STORAGE=mysql'
    )
    $localPath = Join-Path $projectRoot 'backend\.env.mysql'
    foreach ($line in [IO.File]::ReadAllLines($localPath)) {
        if ($line -match '^(SMTP_|EMAIL_OTP_SECRET=|MYSQL_SHIPPING_FEE_MINOR=)') { $lines += $line }
    }
    [IO.File]::WriteAllLines((Join-Path $projectRoot 'backend\.env.cloud'), $lines, [Text.UTF8Encoding]::new($false))
    Write-Output 'Private cloud connection saved. Your local database settings were kept.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secretUri.Dispose()
    $uri=$null
    $credentials=$null
    $lines=$null
}
