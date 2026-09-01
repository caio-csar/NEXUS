$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
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
    -Expected 'Registrar Servidor no Cloud' `
    -Message "Utilitarios deve ter a opcao Registrar Servidor no Cloud."

Assert-Contains `
    -Text $util `
    -Expected 'Get-InfoServidorNexus' `
    -Message "Utilitarios deve coletar informacoes do servidor."

Assert-Contains `
    -Text $util `
    -Expected 'Initial Catalog' `
    -Message "Registro do servidor deve tentar capturar o banco pelo max.ini."

Assert-Contains `
    -Text $util `
    -Expected 'MAX_Manager2.exe' `
    -Message "Registro do servidor deve capturar versao do Manager."

Assert-Contains `
    -Text $util `
    -Expected 'cofEmpRazao' `
    -Message "Registro do servidor deve tentar capturar a empresa pelo banco."

Assert-Contains `
    -Text $util `
    -Expected 'Upload-NexusArquivo' `
    -Message "Registro do servidor deve enviar arquivo para o WebDAV."

Assert-Contains `
    -Text $util `
    -Expected '/REGISTRO_SERVIDORES' `
    -Message "Registro do servidor deve salvar em uma pasta dedicada no cloud."

Assert-NotContains `
    -Text $util `
    -Unexpected 'discord.com/api/webhooks' `
    -Message "Registro do servidor nao deve usar webhook externo."

Write-Host "NEXUS_REGISTRO_SERVIDOR_TESTS OK" -ForegroundColor Green
