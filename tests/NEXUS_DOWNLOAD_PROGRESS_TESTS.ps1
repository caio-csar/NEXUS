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

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Unexpected,
        [string]$Message
    )

    if ($Text.Contains($Unexpected)) {
        throw $Message
    }
}

$downloadStart = $shared.IndexOf("function Download-NexusArquivo")
$formatStart = $shared.IndexOf("function Formatar-BytesAlinhadoNexus")

if ($downloadStart -lt 0 -or $formatStart -lt $downloadStart) {
    throw "Nao foi possivel localizar a funcao Download-NexusArquivo."
}

$download = $shared.Substring($downloadStart, $formatStart - $downloadStart)

Assert-Contains `
    -Text $shared `
    -Expected 'Mostrar-PainelTransferenciaNexus' `
    -Message "Download e upload devem usar painel generico de transferencia."

Assert-Contains `
    -Text $download `
    -Expected 'GetResponseStream' `
    -Message "Download deve usar stream para acompanhar bytes em tempo real."

Assert-Contains `
    -Text $download `
    -Expected 'ContentLength' `
    -Message "Download deve usar ContentLength como total quando disponivel."

Assert-Contains `
    -Text $download `
    -Expected '-Operacao "Download"' `
    -Message "Download deve informar a operacao ao painel."

Assert-Contains `
    -Text $download `
    -Expected '-Enviado $baixado' `
    -Message "Download deve atualizar bytes baixados no painel."

Assert-NotContains `
    -Text $download `
    -Unexpected 'Invoke-WebRequest' `
    -Message "Download monitorado nao deve depender de Invoke-WebRequest."

Write-Host "NEXUS_DOWNLOAD_PROGRESS_TESTS OK" -ForegroundColor Green
