$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$utilPath = Join-Path $repo "modulo_explorar_uteis.ps1"
$util = Get-Content -LiteralPath $utilPath -Raw

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
    -Expected 'UTILITARIOS' `
    -Message "O modulo deve abrir como menu de Utilitarios."

Assert-Contains `
    -Text $util `
    -Expected 'Corrigir WMI' `
    -Message "Utilitarios deve ter a opcao Corrigir WMI."

Assert-Contains `
    -Text $util `
    -Expected 'Instalar/Verificar ODBC' `
    -Message "Utilitarios deve ter a opcao Instalar/Verificar ODBC."

Assert-Contains `
    -Text $util `
    -Expected 'Abrir Pasta do Sistema' `
    -Message "Utilitarios deve ter a opcao Abrir Pasta do Sistema."

Assert-Contains `
    -Text $util `
    -Expected 'Abrir Pasta do Sistema' `
    -Message "Utilitarios deve ter a opcao Abrir Pasta do Sistema."

Assert-NotContains `
    -Text $util `
    -Unexpected 'Limpar Temporarios do NEXUS' `
    -Message "Utilitarios nao deve exibir Limpar Temporarios do NEXUS por enquanto."

Assert-NotContains `
    -Text $util `
    -Unexpected 'Diagnostico do Ambiente' `
    -Message "Utilitarios nao deve exibir Diagnostico do Ambiente por enquanto."

Assert-NotContains `
    -Text $util `
    -Unexpected 'Gerar Log para Suporte' `
    -Message "Utilitarios nao deve exibir Gerar Log para Suporte por enquanto."

Assert-Contains `
    -Text $util `
    -Expected 'Explorar Arquivos Uteis' `
    -Message "O explorador antigo deve continuar disponivel dentro de Utilitarios."

Write-Host "NEXUS_UTILITARIOS_MENU_TESTS OK" -ForegroundColor Green
