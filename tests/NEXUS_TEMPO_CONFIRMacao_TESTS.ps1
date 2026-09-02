$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$shared = Get-Content -LiteralPath (Join-Path $repo "NEXUS_SHARED.ps1") -Raw
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
    -Text $shared `
    -Expected 'NexusProcessoInicioConfirmacao' `
    -Message "Shared deve guardar o inicio do processo no momento da confirmacao."

Assert-Contains `
    -Text $shared `
    -Expected 'Iniciar-TempoConfirmacaoNexus' `
    -Message "Shared deve ter funcao para iniciar tempo por confirmacao."

Assert-Contains `
    -Text $shared `
    -Expected 'Mostrar-TempoDesdeConfirmacaoNexus' `
    -Message "Shared deve ter funcao para mostrar tempo desde a confirmacao."

Assert-Contains `
    -Text $shared `
    -Expected 'Tempo desde confirmacao' `
    -Message "Tempo exibido deve deixar claro que conta desde a confirmacao."

Assert-Contains `
    -Text $shared `
    -Expected 'Pausar-Nexus' `
    -Message "Pausa compartilhada deve participar do fluxo de tempo final."

Assert-Contains `
    -Text $util `
    -Expected 'Pausar-UtilitarioNexus' `
    -Message "Utilitarios deve usar pausa propria que exibe tempo antes de voltar."

Write-Host "NEXUS_TEMPO_CONFIRMACAO_TESTS OK" -ForegroundColor Green
