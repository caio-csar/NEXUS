$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$corePath = Join-Path $repo "NEXUS_CORE.ps1"
$core = Get-Content -LiteralPath $corePath -Raw

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

Assert-NotContains `
    -Text $core `
    -Unexpected 'ENTER - Atualizar NEXUS' `
    -Message "A atualizacao por ENTER deve ser silenciosa e nao aparecer no menu principal."

Assert-Contains `
    -Text $core `
    -Expected 'if ([string]::IsNullOrWhiteSpace($op))' `
    -Message "O menu principal deve tratar ENTER vazio como atualizacao."

Assert-Contains `
    -Text $core `
    -Expected 'Atualizar-CoreNexus' `
    -Message "O core deve ter uma funcao dedicada para recarregar o NEXUS."

Assert-NotContains `
    -Text $core `
    -Unexpected 'Backup para Cloud' `
    -Message "A opcao Backup para Cloud deve sair do menu principal."

Assert-Contains `
    -Text $core `
    -Expected 'Transferencia Cloud' `
    -Message "A opcao de envio de arquivos deve aparecer como Transferencia Cloud."

Assert-Contains `
    -Text $core `
    -Expected '[6] Utilitarios' `
    -Message "O menu principal deve expor Utilitarios na opcao 6."

Assert-Contains `
    -Text $core `
    -Expected 'NEXUS MAXDATA' `
    -Message "O menu principal deve exibir a identidade NEXUS MAXDATA."

Assert-Contains `
    -Text $core `
    -Expected 'PRINCIPAL' `
    -Message "O menu principal deve separar as acoes principais."

Assert-Contains `
    -Text $core `
    -Expected 'CLOUD' `
    -Message "O menu principal deve destacar a area Cloud."

Assert-Contains `
    -Text $core `
    -Expected 'SUPORTE' `
    -Message "O menu principal deve destacar a area de suporte."

Assert-Contains `
    -Text $core `
    -Expected 'SemPausaRetorno = $true' `
    -Message "Utilitarios deve voltar direto ao menu principal sem pausa extra."

Assert-NotContains `
    -Text $core `
    -Unexpected '7 - Explorar Utilitarios' `
    -Message "Explorar Utilitarios deve sair do menu principal."

Assert-NotContains `
    -Text $core `
    -Unexpected '8 - TESTE TEMP - Instalar ODBC' `
    -Message "A opcao temporaria de ODBC deve sair do menu principal."

Write-Host "NEXUS_CORE_MENU_TESTS OK" -ForegroundColor Green
