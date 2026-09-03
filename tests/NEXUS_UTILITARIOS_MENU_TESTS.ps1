$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$utilPath = Join-Path $repo "modulo_utilitarios.ps1"
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
    -Expected 'NEXUS' `
    -Message "O menu de Utilitarios deve exibir a identidade NEXUS."

Assert-Contains `
    -Text $util `
    -Expected 'NEXUS  |  UTILITARIOS' `
    -Message "O menu de Utilitarios deve usar cabecalho sobrio."

Assert-Contains `
    -Text $util `
    -Expected '----------------------------------------' `
    -Message "O menu de Utilitarios deve usar divisoria simples."

Assert-NotContains `
    -Text $util `
    -Unexpected '╔' `
    -Message "O menu de Utilitarios nao deve usar moldura pesada."

Assert-Contains `
    -Text $util `
    -Expected 'SUPORTE' `
    -Message "O menu de Utilitarios deve destacar a area de suporte."

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
    -Expected 'Abrir MaxHub' `
    -Message "Utilitarios deve ter a opcao Abrir MaxHub."

Assert-Contains `
    -Text $util `
    -Expected '18xlV8SG8K1XeaW6yikuGTG38W3sViO9N' `
    -Message "MaxHub deve usar o ID publico informado do Google Drive."

Assert-Contains `
    -Text $util `
    -Expected 'Abrir Pasta do Sistema' `
    -Message "Utilitarios deve ter a opcao Abrir Pasta do Sistema."

Assert-Contains `
    -Text $util `
    -Expected 'NEXUS_MAXHUB' `
    -Message "MaxHub deve ser baixado para uma pasta temporaria propria."

Assert-Contains `
    -Text $util `
    -Expected 'Get-GoogleDriveDownloadUrlNexus' `
    -Message "MaxHub deve tratar a tela de confirmacao do Google Drive."

Assert-Contains `
    -Text $util `
    -Expected 'drive.usercontent.google.com/download' `
    -Message "MaxHub deve baixar pelo endpoint confirmado do Google Drive."

Assert-Contains `
    -Text $util `
    -Expected 'MaxHub.rar' `
    -Message "MaxHub deve baixar o pacote RAR publico."

Assert-Contains `
    -Text $util `
    -Expected 'Test-ArquivoRarNexus' `
    -Message "NEXUS deve validar se o download retornou um RAR real."

Assert-Contains `
    -Text $util `
    -Expected '& $sevenZip x' `
    -Message "NEXUS deve extrair o pacote MaxHub antes de abrir."

Assert-Contains `
    -Text $util `
    -Expected 'Get-ChildItem -LiteralPath $pastaExtracao -Filter "*.exe"' `
    -Message "NEXUS deve localizar o executavel extraido do MaxHub."

Assert-Contains `
    -Text $util `
    -Expected 'Start-Process -FilePath $exe.FullName -PassThru -Wait' `
    -Message "NEXUS deve abrir o MaxHub uma unica vez e aguardar fechamento."

Assert-Contains `
    -Text $util `
    -Expected 'Remove-Item -LiteralPath $pastaTemp -Recurse -Force' `
    -Message "NEXUS deve remover o executavel temporario ao fechar o MaxHub."

Assert-Contains `
    -Text $util `
    -Expected 'Test-ArquivoExecutavelNexus' `
    -Message "NEXUS deve validar se o download retornou um executavel real."

Assert-Contains `
    -Text $util `
    -Expected '  [3] Abrir MaxHub' `
    -Message "MaxHub deve ficar na opcao 3."

Assert-Contains `
    -Text $util `
    -Expected '  [4] Abrir Pasta do Sistema' `
    -Message "Abrir Pasta do Sistema deve ficar na opcao 4."

Assert-NotContains `
    -Text $util `
    -Unexpected '  [3] Registrar Servidor no Cloud' `
    -Message "Registro de servidor deve ficar dormente fora do menu."

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

Assert-NotContains `
    -Text $util `
    -Unexpected 'Explorar Arquivos Uteis' `
    -Message "Explorar Arquivos Uteis deve sair de Utilitarios."

Assert-Contains `
    -Text $util `
    -Expected '"0" { return }' `
    -Message "A opcao 0 deve sair direto do modulo de Utilitarios."

Write-Host "NEXUS_UTILITARIOS_MENU_TESTS OK" -ForegroundColor Green
