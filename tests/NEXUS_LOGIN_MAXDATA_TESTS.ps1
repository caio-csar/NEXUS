$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$scriptSql = Join-Path $repo "Scripts_Uteis/Configurar-LoginMaxdata.ps1"
$menu = Get-Content -LiteralPath (Join-Path $repo "modulo_utilitarios.ps1") -Raw
if (-not (Test-Path -LiteralPath $scriptSql)) { throw 'Script SQL nao encontrado.' }

$tokens = $null
$erros = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptSql, [ref]$tokens, [ref]$erros)
if ($erros.Count -gt 0) { throw "Erro de sintaxe: $($erros | Out-String)" }

$src = Get-Content -LiteralPath $scriptSql -Raw
foreach ($item in @(
    "['Data Source']", "['Initial Catalog']", "['Integrated Security']",
    "['Connect Timeout']", "['Application Name']", "'MSSQLSERVER'",
    "'MSSQL$*'", "'localhost'", 'Get-Service',
    'CREATE LOGIN [maxdata]', 'DEFAULT_DATABASE = [master]',
    'DEFAULT_LANGUAGE = [Brazilian]', 'CHECK_POLICY = ON',
    'CHECK_EXPIRATION = OFF', 'ALTER SERVER ROLE',
    'CREATE USER [maxdata] FOR LOGIN [maxdata] WITH DEFAULT_SCHEMA = [dbo]',
    'sys.server_principals', 'sys.server_role_members',
    'sys.database_principals', 'SUSER_SID',
    'Read-Host', '-AsSecureString', 'JA EXISTIA',
    'CONCLUIDO', 'Nenhuma instancia SQL Server local'
)) {
    if (-not $src.Contains($item)) { throw "Etapa SQL ausente: $item" }
}
if ($src.Contains('max5699')) { throw 'Nao publicar senha estatica de sysadmin.' }

foreach ($item in @(
    '[7] Criar usuarios no banco',
    '"7" { Configurar-LoginMaxdataNexus; Pausar-UtilitarioNexus -Nome "criar usuarios no banco" }',
    'Scripts_Uteis/Configurar-LoginMaxdata.ps1'
)) {
    if (-not $menu.Contains($item)) { throw "Menu incompleto: $item" }
}
if ($menu.Contains('[7] Configurar Login SQL Maxdata')) { throw 'Nome anterior ainda exibido.' }

foreach ($nome in @('New-ConexaoNexusSql', 'Get-InstanciasNexusSql')) {
    $definicoes = @($ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nome
    }, $true))
    if ($definicoes.Count -ne 1) { throw "Funcao SQL ausente: $nome" }
    . ([scriptblock]::Create($definicoes[0].Extent.Text))
}

# Regressao real: testa a construcao da connection string que falhava com 'DataSource'.
$conexao = New-ConexaoNexusSql -Instancia 'localhost\SQLEXPRESS' -Timeout 2
try {
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder -ArgumentList $conexao.ConnectionString
    if ($builder['Data Source'] -ne 'localhost\SQLEXPRESS') { throw 'Data Source incorreto.' }
    if ($builder['Initial Catalog'] -ne 'master') { throw 'Catalogo incorreto.' }
    if (-not $builder['Integrated Security']) { throw 'Autenticacao Windows ausente.' }
}
finally { $conexao.Dispose() }

# Simula servicos locais: MSSQLSERVER conecta como localhost, sem sufixo.
function Get-Service {
    [CmdletBinding()]
    param([string[]]$Name)
    @(
        [pscustomobject]@{ Name='MSSQLSERVER'; Status='Running' },
        [pscustomobject]@{ Name='MSSQL$APP'; Status='Running' },
        [pscustomobject]@{ Name='MSSQL$OFF'; Status='Stopped' }
    )
}
$instancias = @(Get-InstanciasNexusSql)
if ($instancias.Count -ne 2 -or
    $instancias -notcontains 'localhost' -or
    $instancias -notcontains 'localhost\APP' -or
    $instancias -contains 'localhost\MSSQLSERVER') {
    throw "Deteccao automatica incorreta: $($instancias -join ', ')"
}

Write-Host 'NEXUS_LOGIN_MAXDATA_TESTS OK' -ForegroundColor Green
