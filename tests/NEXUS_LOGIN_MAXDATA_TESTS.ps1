$ErrorActionPreference = "Stop"

$raiz = Split-Path -Parent $PSScriptRoot
$scriptSql = Join-Path $raiz "Scripts_Uteis/Configurar-LoginMaxdata.ps1"
$scriptMenu = Join-Path $raiz "modulo_utilitarios.ps1"

if (-not (Test-Path -LiteralPath $scriptSql)) {
    throw "Script de login SQL maxdata nao encontrado."
}

$erros = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptSql, [ref]$tokens, [ref]$erros) | Out-Null
if ($erros.Count -gt 0) {
    throw "Falha de sintaxe em Configurar-LoginMaxdata.ps1: $($erros | Out-String)"
}

$codigo = Get-Content -LiteralPath $scriptSql -Raw
$menu = Get-Content -LiteralPath $scriptMenu -Raw
foreach ($necessario in @(
    'CHECK_POLICY = ON',
    'CHECK_EXPIRATION = OFF',
    'DEFAULT_DATABASE = [master]',
    'DEFAULT_LANGUAGE = [Brazilian]',
    'CREATE LOGIN [maxdata]',
    'CREATE USER [maxdata] FOR LOGIN [maxdata] WITH DEFAULT_SCHEMA = [dbo]',
    'sys.server_principals',
    'sys.server_role_members',
    'sys.database_principals',
    'SUSER_SID(@Login)',
    'Read-Host ''Nova senha para maxdata'' -AsSecureString',
    'Obter-TextoSeguro',
    'IntegratedSecurity = $true',
    "sp_addsrvrolemember",
    'JA EXISTIA',
    'CONFIGURACAO CONCLUIDA COM SUCESSO',
    'if ($resposta -ne ''S'')',
    'exit 1'
)) {
    if (-not $codigo.Contains($necessario)) {
        throw "Rotina de login SQL incompleta: $necessario"
    }
}

foreach ($role in @(
    'sysadmin', 'securityadmin', 'serveradmin', 'setupadmin',
    'processadmin', 'diskadmin', 'dbcreator', 'bulkadmin'
)) {
    if (-not $codigo.Contains("'$role'")) {
        throw "Role solicitada nao encontrada: $role"
    }
}

foreach ($itemMenu in @(
    '[7] Configurar Login SQL Maxdata',
    '"7" { Configurar-LoginMaxdataNexus; Pausar-UtilitarioNexus -Nome "login SQL maxdata" }',
    'Scripts_Uteis/Configurar-LoginMaxdata.ps1'
)) {
    if (-not $menu.Contains($itemMenu)) {
        throw "Menu de Utilitarios incompleto: $itemMenu"
    }
}

# Protecao contra publicar no repositorio publico a senha compartilhada do cliente.
if ($codigo.Contains('max5699')) {
    throw "O script nao deve distribuir senha fixa de sysadmin."
}
if ($codigo -match 'SqlPassword\s*=\s*"') {
    throw "Nao registrar senha SQL em texto puro."
}

Write-Host "NEXUS_LOGIN_MAXDATA_TESTS OK" -ForegroundColor Green
