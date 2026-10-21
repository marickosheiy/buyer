$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$package = Join-Path $projectRoot ('build\cloud-api-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $package | Out-Null
$files = @('Dockerfile','.dockerignore','requirements-mysql.txt','requirements-hosting.txt','server.py','mysql_store.py','mobile_auth.py','host_api.py','schema.sql','mobile_schema.sql','aiven-ca.pem')
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $backendRoot $file) -Destination (Join-Path $package $file)
}
# The CA certificate is public trust material, not a database password.
$dockerfile = Join-Path $package 'Dockerfile'
$source = [IO.File]::ReadAllText($dockerfile).Replace('EXPOSE 8000', "COPY aiven-ca.pem ./`nEXPOSE 8000")
[IO.File]::WriteAllText($dockerfile, $source, [Text.UTF8Encoding]::new($false))
Add-Content -LiteralPath (Join-Path $package '.dockerignore') -Value '!aiven-ca.pem'
@{directory=$package;files=$files} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectRoot 'build\cloud-api-package.json')
Write-Output 'API upload package prepared: source code and public CA certificate only.'
Write-Output 'Passwords, account data, documents and local archives are excluded.'
