$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$core = Get-Content -LiteralPath (Join-Path $repo "NEXUS_CORE.ps1") -Raw
$util = Get-Content -LiteralPath (Join-Path $repo "modulo_utilitarios.ps1") -Raw

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Expected,
        [string]$Message
    )

    if (-not $Text.Contains($Expected)) {
        throw $Message
    }
}

Assert-Contains `
    -Text $core `
    -Expected 'Get-UrlSemCacheNexus' `
    -Message "Core deve montar URL com cache-buster para scripts baixados."

Assert-Contains `
    -Text $core `
    -Expected 'Cache-Control' `
    -Message "Core deve enviar header anti-cache nos downloads."

Assert-Contains `
    -Text $util `
    -Expected 'Get-UrlSemCacheUtilitario' `
    -Message "Utilitarios deve montar URL com cache-buster para arquivos publicos."

Assert-Contains `
    -Text $util `
    -Expected 'Cache-Control' `
    -Message "Utilitarios deve enviar header anti-cache nos downloads."

Write-Host "NEXUS_CACHE_DOWNLOAD_TESTS OK" -ForegroundColor Green
