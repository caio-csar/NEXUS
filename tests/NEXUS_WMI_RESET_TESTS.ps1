$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$wmiPath = Join-Path $repo "Scripts_Uteis\wmi_reset.bat"
$util = Get-Content -LiteralPath (Join-Path $repo "modulo_utilitarios.ps1") -Raw
$wmi = Get-Content -LiteralPath $wmiPath -Raw

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

Assert-Contains `
    -Text $util `
    -Expected 'Scripts_Uteis/wmi_reset.bat' `
    -Message "Utilitarios deve baixar o script WMI publicado no repositorio."

Assert-Contains `
    -Text $wmi `
    -Expected 'NEXUS_Reset_WMI_PosReinicio' `
    -Message "WMI deve criar uma tarefa automatica para concluir apos reinicio quando houver bloqueio."

Assert-Contains `
    -Text $wmi `
    -Expected 'schtasks /Create' `
    -Message "WMI deve agendar a execucao no proximo boot."

Assert-Contains `
    -Text $wmi `
    -Expected 'schtasks /Delete' `
    -Message "WMI deve remover a tarefa agendada ao concluir."

Assert-Contains `
    -Text $wmi `
    -Expected '%ProgramData%\NEXUS' `
    -Message "WMI deve persistir uma copia fora do TEMP para sobreviver ao reinicio."

Assert-NotContains `
    -Text $wmi `
    -Unexpected 'rode este BAT logo apos iniciar' `
    -Message "WMI nao deve depender de execucao manual apos reinicio."

Write-Host "NEXUS_WMI_RESET_TESTS OK" -ForegroundColor Green
