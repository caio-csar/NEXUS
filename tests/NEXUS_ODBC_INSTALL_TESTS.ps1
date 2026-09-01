$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$core = Get-Content -LiteralPath (Join-Path $repo "NEXUS_CORE.ps1") -Raw
$installer = Get-Content -LiteralPath (Join-Path $repo "modulo_instalador.ps1") -Raw
$util = Get-Content -LiteralPath (Join-Path $repo "modulo_explorar_uteis.ps1") -Raw
$tempModulePath = Join-Path $repo "modulo_testar_odbc.ps1"

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

function Assert-FileExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw $Message
    }
}

if ($core.Contains('TESTE TEMP - Instalar ODBC')) {
    throw "A opcao temporaria de ODBC deve sair do menu principal."
}

Assert-Contains `
    -Text $util `
    -Expected 'Instalar/Verificar ODBC' `
    -Message "Utilitarios deve expor a instalacao/verificacao ODBC."

Assert-Contains `
    -Text $util `
    -Expected 'modulo_testar_odbc.ps1' `
    -Message "Utilitarios deve chamar modulo_testar_odbc.ps1."

Assert-Contains `
    -Text $installer `
    -Expected 'IACCEPTMSODBCSQLLICENSETERMS=YES' `
    -Message "ODBC Driver deve aceitar licenca para instalacao silenciosa."

Assert-Contains `
    -Text $installer `
    -Expected 'IACCEPTSQLNCLILICENSETERMS=YES' `
    -Message "SQL Native Client deve aceitar licenca para instalacao silenciosa."

Assert-Contains `
    -Text $installer `
    -Expected '-PassThru' `
    -Message "Instalar-MSI deve capturar ExitCode do msiexec."

Assert-Contains `
    -Text $installer `
    -Expected 'ExitCode' `
    -Message "Instalar-MSI deve validar o codigo de saida."

Assert-Contains `
    -Text $installer `
    -Expected 'Test-DependenciasOdbcInstaladas' `
    -Message "Instalador deve validar dependencias ODBC apos instalar."

Assert-Contains `
    -Text $installer `
    -Expected 'Test-SqlNativeClientInstalado' `
    -Message "Instalador deve ter validacao especifica para SQL Native Client."

Assert-Contains `
    -Text $installer `
    -Expected 'SQL Server.*Native Client' `
    -Message "Validacao do SQL Native Client deve aceitar nome com versao no meio."

Assert-Contains `
    -Text $installer `
    -Expected 'ODBCINST.INI\SQL Server Native Client 11.0' `
    -Message "Validacao do SQL Native Client deve checar o driver ODBC registrado."

Assert-Contains `
    -Text $installer `
    -Expected 'installers/odbc/sqlnclix64.msi' `
    -Message "SQL Native Client deve vir do instalador embutido no repositorio."

Assert-Contains `
    -Text $installer `
    -Expected 'installers/odbc/msodbcsqlx64.msi' `
    -Message "ODBC Driver deve vir do instalador embutido no repositorio."

Assert-Contains `
    -Text $installer `
    -Expected 'Get-NexusRawUrl' `
    -Message "Instalador deve montar URLs RAW do proprio repositorio."

Assert-FileExists `
    -Path $tempModulePath `
    -Message "modulo_testar_odbc.ps1 deve existir para teste ODBC pelo menu de Utilitarios."

$tempModule = Get-Content -LiteralPath $tempModulePath -Raw

Assert-Contains `
    -Text $tempModule `
    -Expected 'Instalar-DependenciasOdbc' `
    -Message "Modulo ODBC deve chamar a instalacao automatizada de ODBC."

Assert-Contains `
    -Text $tempModule `
    -Expected 'Test-SqlNativeClientInstalado' `
    -Message "Modulo ODBC deve validar SQL Native Client pelo nome correto."

Assert-Contains `
    -Text $tempModule `
    -Expected 'installers/odbc/sqlnclix64.msi' `
    -Message "Modulo ODBC deve usar o SQL Native Client embutido no repositorio."

Assert-Contains `
    -Text $tempModule `
    -Expected 'installers/odbc/msodbcsqlx64.msi' `
    -Message "Modulo ODBC deve usar o ODBC Driver embutido no repositorio."

Write-Host "NEXUS_ODBC_INSTALL_TESTS OK" -ForegroundColor Green
