param(
    [Parameter(Mandatory = $true)]
    [string]$JarPath
)

$ErrorActionPreference = 'Stop'
$resolvedJar = (Resolve-Path -LiteralPath $JarPath).Path
$temporary = Join-Path ([IO.Path]::GetTempPath()) ("nieve-java-scan-" + [guid]::NewGuid())
$patterns = [ordered]@{
    private_key = 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
    email = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    windows_absolute_path = '(?i)[A-Z]:\\[^\r\n"'']+'
    smtp_password = '(?i)(smtp|email)[._-]?(password|contrasena)'
    bearer_credential = '(?i)Bearer\s+[A-Za-z0-9._~-]{20,}'
}

try {
    New-Item -ItemType Directory -Path $temporary | Out-Null
    Push-Location $temporary
    try {
        & jar xf $resolvedJar
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo abrir el JAR"
        }
    } finally {
        Pop-Location
    }

    $files = Get-ChildItem -LiteralPath $temporary -Recurse -File
    $findings = @()
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($temporary.Length + 1)
        $firstParty = $relativePath -like 'com\atorbado\*' -or
            $relativePath -eq 'edition.properties'
        $content = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($file.FullName))
        foreach ($name in $patterns.Keys) {
            if (($name -eq 'email' -or $name -eq 'windows_absolute_path') -and
                -not $firstParty) {
                continue
            }
            if ([regex]::IsMatch($content, $patterns[$name])) {
                $findings += "$name en $relativePath"
            }
        }
    }

    if ($findings.Count -gt 0) {
        $findings | ForEach-Object { Write-Error $_ }
        throw "El artefacto contiene indicadores sensibles"
    }
    Write-Output "ARTEFACTO_SIN_INDICADORES_SENSIBLES"
} finally {
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
}
