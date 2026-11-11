# NEXUS - Criar/verificar login e usuario SQL maxdata
# Requer Windows Authentication com permissao sysadmin na instancia escolhida.
# Nao armazena senha no codigo, arquivo, log ou argumentos de processo.
$ErrorActionPreference = 'Stop'
$nomeLogin = 'maxdata'
$rolesSolicitadas = @(
    'sysadmin', 'securityadmin', 'serveradmin', 'setupadmin',
    'processadmin', 'diskadmin', 'dbcreator', 'bulkadmin'
)

function New-ConexaoSql {
    param([Parameter(Mandatory)][string]$Instancia, [int]$Timeout = 3)
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder.DataSource = $Instancia
    $builder.InitialCatalog = 'master'
    $builder.IntegratedSecurity = $true
    $builder.ConnectTimeout = $Timeout
    $builder.ApplicationName = 'NEXUS - Login maxdata'
    # Usa a negociacao de criptografia padrao do driver para a instancia.
    $conexao = New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
    $conexao.Open()
    return $conexao
}

function Invoke-SqlNexus {
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Conexao,
        [Parameter(Mandatory)][string]$Sql,
        [hashtable]$Parametros = @{},
        [switch]$Escalar
    )
    $comando = $Conexao.CreateCommand()
    $comando.CommandText = $Sql
    $comando.CommandTimeout = 30
    try {
        foreach ($nome in $Parametros.Keys) {
            $parametro = $comando.Parameters.Add("@$nome", [System.Data.SqlDbType]::NVarChar, 128)
            $parametro.Value = [string]$Parametros[$nome]
        }
        if ($Escalar) { return $comando.ExecuteScalar() }
        [void]$comando.ExecuteNonQuery()
    }
    finally {
        $comando.Dispose()
    }
}

function Obter-TextoSeguro {
    param([Parameter(Mandatory)][Security.SecureString]$Senha)
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Senha)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Obter-PadraoMaxIni {
    $pastaMax = Join-Path $env:SystemDrive 'MAX'
    $ini = Join-Path $pastaMax 'max.ini'
    $retorno = @{ Instancia = ''; Banco = '' }
    if (-not (Test-Path -LiteralPath $ini)) { return $retorno }

    $conteudo = Get-Content -LiteralPath $ini -Raw -ErrorAction SilentlyContinue
    if (-not $conteudo) { return $retorno }

    $mServidor = [regex]::Match($conteudo, '(?im)(?:^|;)\s*(?:Data\s+Source|Server|Address)\s*=\s*([^;\r\n]+)')
    $mBanco = [regex]::Match($conteudo, '(?im)(?:^|;)\s*(?:Initial\s+Catalog|Database)\s*=\s*([^;\r\n]+)')
    if ($mServidor.Success) { $retorno.Instancia = $mServidor.Groups[1].Value.Trim() }
    if ($mBanco.Success) { $retorno.Banco = $mBanco.Groups[1].Value.Trim() }
    return $retorno
}

$conexao = $null
$loginCriado = $false
$usuarioCriado = $false
$rolesCriadas = 0

try {
    Write-Host ''
    Write-Host 'NEXUS | CONFIGURAR LOGIN E USUARIO MAXDATA' -ForegroundColor Cyan
    Write-Host 'Requer Windows Authentication com permissao sysadmin no SQL Server.' -ForegroundColor Yellow
    Write-Host 'Nao altera senhas ou exclui logins/usuarios ja existentes.' -ForegroundColor DarkGray
    Write-Host ''

    $configIni = Obter-PadraoMaxIni
    $candidatas = New-Object 'System.Collections.Generic.List[string]'
    foreach ($nome in @($configIni.Instancia, 'localhost', '.\SQLEXPRESS')) {
        if (-not [string]::IsNullOrWhiteSpace($nome) -and -not $candidatas.Contains($nome)) {
            $candidatas.Add($nome)
        }
    }

    $validas = New-Object 'System.Collections.Generic.List[string]'
    foreach ($instancia in $candidatas) {
        try {
            $teste = New-ConexaoSql -Instancia $instancia -Timeout 2
            $validas.Add($instancia)
            $teste.Dispose()
        }
        catch { }
    }

    $instanciaSelecionada = ''
    if ($validas.Count -eq 1) {
        $instanciaSelecionada = $validas[0]
    }
    elseif ($validas.Count -gt 1) {
        Write-Host 'Instancias detectadas:' -ForegroundColor Cyan
        for ($i=0; $i -lt $validas.Count; $i++) {
            Write-Host ('  [{0}] {1}' -f ($i+1), $validas[$i])
        }
        $numero = Read-Host 'Numero da instancia (ENTER = 1)'
        if ([string]::IsNullOrWhiteSpace($numero)) { $numero = '1' }
        $escolha = 0
        if (-not [int]::TryParse($numero, [ref]$escolha) -or $escolha -lt 1 -or $escolha -gt $validas.Count) {
            throw 'Instancia selecionada invalida. Nenhuma alteracao realizada.'
        }
        $instanciaSelecionada = $validas[$escolha - 1]
    }
    else {
        $instanciaSelecionada = (Read-Host 'Instancia SQL Server (ex.: localhost\SQLEXPRESS)').Trim()
        if ([string]::IsNullOrWhiteSpace($instanciaSelecionada)) {
            throw 'Nenhuma instancia SQL informada. Nenhuma alteracao realizada.'
        }
    }

    $conexao = New-ConexaoSql -Instancia $instanciaSelecionada -Timeout 5

    $admin = [int](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql "SELECT ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)")
    if ($admin -ne 1) {
        throw 'Sua conta Windows nao possui sysadmin nesta instancia. Use uma conta administradora do SQL Server.'
    }

    $bancoPadrao = [string]$configIni.Banco
    if (-not [string]::IsNullOrWhiteSpace($bancoPadrao)) {
        $banco = (Read-Host "Banco de dados de destino (ENTER = $bancoPadrao)").Trim()
        if (-not $banco) { $banco = $bancoPadrao }
    }
    else {
        $banco = (Read-Host 'Banco de dados de destino (nao use master)').Trim()
    }
    if (-not $banco) { throw 'Informe um banco de dados. Nenhuma alteracao realizada.' }

    $bancoEncontrado = [int](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql @'
SELECT COUNT(1) FROM sys.databases
WHERE name = @Banco AND database_id > 4 AND state_desc = N'ONLINE';
'@ -Parametros @{ Banco=$banco })

    if ($bancoEncontrado -ne 1) {
        throw 'Banco nao encontrado, indisponivel ou banco de sistema. Nenhuma alteracao realizada.'
    }

    Write-Host ''
    Write-Host ('Instancia: ' + $instanciaSelecionada) -ForegroundColor Cyan
    Write-Host ('Banco:     ' + $banco) -ForegroundColor Cyan
    Write-Host 'Conta:     maxdata' -ForegroundColor Cyan
    Write-Host 'Permissoes solicitadas: sysadmin e demais funcoes fixas de servidor.' -ForegroundColor Yellow
    Write-Host 'ATENCAO: sysadmin concede controle total da instancia SQL Server.' -ForegroundColor Yellow
    $resposta = (Read-Host 'Confirma a configuracao nesta instancia e banco? (S/N)').Trim().ToUpperInvariant()
    if ($resposta -ne 'S') {
        Write-Host 'Operacao cancelada. Nenhuma alteracao realizada.' -ForegroundColor Yellow
        exit 0
    }

    $loginExistente = [int](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql @'
SELECT COUNT(1) FROM sys.server_principals WHERE name = @Login;
'@ -Parametros @{Login=$nomeLogin})

    if ($loginExistente -eq 0) {
        Write-Host 'Login ainda nao existe. Informe uma senha forte (nao sera salva pelo NEXUS).' -ForegroundColor Cyan
        $senhaSegura = Read-Host 'Nova senha para maxdata' -AsSecureString
        $confirmacaoSegura = Read-Host 'Confirme a senha' -AsSecureString
        $senhaTexto = $null
        $confirmacaoTexto = $null
        try {
            $senhaTexto = Obter-TextoSeguro -Senha $senhaSegura
            $confirmacaoTexto = Obter-TextoSeguro -Senha $confirmacaoSegura
            if ($senhaTexto -cne $confirmacaoTexto) {
                throw 'As senhas nao coincidem. Login nao criado.'
            }
            if ([string]::IsNullOrWhiteSpace($senhaTexto) -or $senhaTexto.Length -gt 128) {
                throw 'Senha deve ter de 1 a 128 caracteres. Login nao criado.'
            }

            # Parametro ADO.NET impede senha no codigo ou na linha de comando.
            # DDL exige literal para PASSWORD; o literal e montado apenas dentro do SQL.
            Invoke-SqlNexus -Conexao $conexao -Sql @'
DECLARE @ddl nvarchar(max) =
    N'CREATE LOGIN [maxdata] WITH PASSWORD = ' + NCHAR(39) +
    REPLACE(@Senha, NCHAR(39), NCHAR(39) + NCHAR(39)) + NCHAR(39) +
    N', DEFAULT_DATABASE = [master], DEFAULT_LANGUAGE = [Brazilian], CHECK_POLICY = ON, CHECK_EXPIRATION = OFF';
EXEC sys.sp_executesql @ddl;
'@ -Parametros @{Senha=$senhaTexto}
            $loginCriado = $true
            Write-Host 'LOGIN maxdata CRIADO.' -ForegroundColor Green
        }
        finally {
            $senhaTexto = $null
            $confirmacaoTexto = $null
            $senhaSegura = $null
            $confirmacaoSegura = $null
        }
    }
    else {
        $tipo = [string](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql @'
SELECT type_desc FROM sys.server_principals WHERE name = @Login;
'@ -Parametros @{Login=$nomeLogin})
        if ($tipo -ne 'SQL_LOGIN') {
            throw "Ja existe um principal 'maxdata' do tipo $tipo; nao sera alterado."
        }
        Write-Host 'LOGIN maxdata JA EXISTIA. Senha preservada.' -ForegroundColor Yellow
    }

    foreach ($role in $rolesSolicitadas) {
        $existe = [int](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql @'
SELECT COUNT(1)
FROM sys.server_role_members AS rm
JOIN sys.server_principals AS r ON r.principal_id = rm.role_principal_id
JOIN sys.server_principals AS m ON m.principal_id = rm.member_principal_id
WHERE r.name = @Role AND m.name = @Login;
'@ -Parametros @{Role=$role;Login=$nomeLogin})

        if ($existe -eq 1) {
            Write-Host ("ROLE $role JA EXISTIA.") -ForegroundColor Yellow
        }
        else {
            Invoke-SqlNexus -Conexao $conexao -Sql @'
EXEC master.dbo.sp_addsrvrolemember @loginame = @Login, @rolename = @Role;
'@ -Parametros @{Role=$role;Login=$nomeLogin}
            $rolesCriadas++
            Write-Host ("ROLE $role ADICIONADA.") -ForegroundColor Green
        }
    }

    $conexao.ChangeDatabase($banco)

    $usuarioExistente = [int](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql @'
SELECT COUNT(1) FROM sys.database_principals WHERE name = @Login;
'@ -Parametros @{Login=$nomeLogin})

    $usuarioMapeado = [int](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql @'
SELECT COUNT(1) FROM sys.database_principals
WHERE name = @Login AND sid = SUSER_SID(@Login);
'@ -Parametros @{Login=$nomeLogin})

    if ($usuarioExistente -eq 1) {
        if ($usuarioMapeado -ne 1) {
            throw 'O usuario maxdata ja existe neste banco, mas esta mapeado a outro login. Nao foi alterado.'
        }
        Write-Host 'USUARIO maxdata JA EXISTIA neste banco.' -ForegroundColor Yellow
    }
    else {
        $outroUsuario = [int](Invoke-SqlNexus -Conexao $conexao -Escalar -Sql @'
SELECT COUNT(1) FROM sys.database_principals
WHERE name <> @Login AND sid = SUSER_SID(@Login);
'@ -Parametros @{Login=$nomeLogin})
        if ($outroUsuario -gt 0) {
            throw 'Este login ja esta mapeado a outro usuario no banco. Nao foi criado usuario duplicado.'
        }

        Invoke-SqlNexus -Conexao $conexao -Sql @'
CREATE USER [maxdata] FOR LOGIN [maxdata] WITH DEFAULT_SCHEMA = [dbo];
'@
        $usuarioCriado = $true
        Write-Host 'USUARIO maxdata CRIADO neste banco.' -ForegroundColor Green
    }

    Write-Host ''
    if (-not $loginCriado -and -not $usuarioCriado -and $rolesCriadas -eq 0) {
        Write-Host 'JA EXISTIA: login, permissoes e usuario maxdata estavam configurados.' -ForegroundColor Yellow
    }
    else {
        Write-Host 'CONFIGURACAO CONCLUIDA COM SUCESSO.' -ForegroundColor Green
        Write-Host ("Login criado: $loginCriado | Roles adicionadas: $rolesCriadas | Usuario criado: $usuarioCriado")
    }
}
catch {
    Write-Host ''
    Write-Host ('FALHA NA CONFIGURACAO: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Algumas etapas anteriores podem ter sido concluidas. Execute novamente para verificar.' -ForegroundColor Yellow
    exit 1
}
finally {
    if ($null -ne $conexao) { $conexao.Dispose() }
}
