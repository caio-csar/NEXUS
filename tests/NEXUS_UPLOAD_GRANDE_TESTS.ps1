$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$shared = Get-Content -LiteralPath (Join-Path $repo "NEXUS_SHARED.ps1") -Raw

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
    -Text $shared `
    -Expected 'Upload-NexusArquivoChunked' `
    -Message "Upload grande deve usar funcao chunked."

Assert-Contains `
    -Text $shared `
    -Expected 'uploads/$user/$uploadId' `
    -Message "Upload grande deve usar endpoint de uploads chunked do Nextcloud."

Assert-Contains `
    -Text $shared `
    -Expected 'OC-Total-Length' `
    -Message "Upload chunked deve informar o tamanho total ao servidor."

Assert-Contains `
    -Text $shared `
    -Expected 'Destination' `
    -Message "Upload chunked deve informar o destino final em cada etapa."

Assert-Contains `
    -Text $shared `
    -Expected '.file' `
    -Message "Upload chunked deve finalizar movendo .file para o destino final."

Assert-Contains `
    -Text $shared `
    -Expected 'MOVE' `
    -Message "Upload chunked deve montar o arquivo final com MOVE."

Assert-Contains `
    -Text $shared `
    -Expected 'TamanhoChunk' `
    -Message "Upload deve expor tamanho de chunk configuravel."

Write-Host "NEXUS_UPLOAD_GRANDE_TESTS OK" -ForegroundColor Green
