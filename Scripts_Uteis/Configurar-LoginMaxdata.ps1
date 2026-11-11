# NEXUS - Criar usuarios no banco
# Instancias SQL locais em execucao. Login/roles por instancia; usuario no banco escolhido.
$ErrorActionPreference = 'Stop'
$roles = @('sysadmin','securityadmin','serveradmin','setupadmin','processadmin','diskadmin','dbcreator','bulkadmin')

function New-ConexaoNexusSql {
    param([string]$Instancia, [int]$Timeout = 3)

    # Chaves canonicas do SqlConnectionStringBuilder (nao "DataSource").
    $cs = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $cs['Data Source'] = $Instancia
    $cs['Initial Catalog'] = 'master'
    $cs['Integrated Security'] = $true
    $cs['Connect Timeout'] = $Timeout
    $cs['Application Name'] = 'NEXUS'
    return (New-Object System.Data.SqlClient.SqlConnection -ArgumentList $cs.ConnectionString)
}

function Invoke-NexusSql {
    param(
        [System.Data.SqlClient.SqlConnection]$Conexao,
        [string]$Sql,
        [hashtable]$Parametros = @{},
        [switch]$Scalar
    )
    $cmd = $Conexao.CreateCommand()
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 30
    try {
        foreach ($key in $Parametros.Keys) {
            $p = $cmd.Parameters.Add("@$key", [System.Data.SqlDbType]::NVarChar, 4000)
            $p.Value = [string]$Parametros[$key]
        }
        if ($Scalar) { return $cmd.ExecuteScalar() }
        [void]$cmd.ExecuteNonQuery()
    }
    finally { $cmd.Dispose() }
}

function Get-InstanciasNexusSql {
    $lista = New-Object 'System.Collections.Generic.List[string]'
    $servicos = @(Get-Service -Name 'MSSQLSERVER', 'MSSQL$*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Running' })
    foreach ($svc in $servicos) {
        $instancia = if ($svc.Name -eq 'MSSQLSERVER') {
            'localhost'
        } else {
            'localhost\' + $svc.Name.Substring(6)
        }
        if (-not $lista.Contains($instancia)) { $lista.Add($instancia) }
    }

    # Em ambientes sem servicos detectados, testa os nomes comuns.
    if ($lista.Count -eq 0) {
        foreach ($candidato in @('localhost', 'localhost\SQLEXPRESS')) {
            try {
                $teste = New-ConexaoNexusSql -Instancia $candidato -Timeout 2
                try {
                    $teste.Open()
                    $lista.Add($candidato)
                }
                finally { $teste.Dispose() }
            }
            catch { }
        }
    }
    return $lista.ToArray()
}

function Get-BancoMaxIni {
    $ini = Join-Path $env:SystemDrive 'MAX\max.ini'
    if (-not (Test-Path -LiteralPath $ini)) { return '' }
    $conteudo = Get-Content -LiteralPath $ini -Raw -ErrorAction SilentlyContinue
    if (-not $conteudo) { return '' }
    $matchBanco = [regex]::Match($conteudo, '(?i)(?:^|;)\s*(?:Initial Catalog|Database)\s*=\s*([^;\r\n]+)')
    if ($matchBanco.Success) { return $matchBanco.Groups[1].Value.Trim() }
    return ''
}

function Get-BancosNexusSql {
    param([System.Data.SqlClient.SqlConnection]$Conexao)
    $cmd = $Conexao.CreateCommand()
    $cmd.CommandText = "SELECT name FROM sys.databases WHERE database_id > 4 AND state_desc = 'ONLINE' ORDER BY name"
    $resultado = New-Object 'System.Collections.Generic.List[string]'
    try {
        $reader = $cmd.ExecuteReader()
        try {
            while ($reader.Read()) { $resultado.Add([string]$reader.GetString(0)) }
        }
        finally { $reader.Dispose() }
    }
    finally { $cmd.Dispose() }
    return $resultado.ToArray()
}

function Escolher-BancoNexusSql {
    param([string[]]$Bancos, [string]$Sugestao, [string]$Instancia)
    if ($Bancos.Count -eq 0) { return '' }
    $sugerido = @($Bancos | Where-Object { $_ -eq $Sugestao } | Select-Object -First 1)
    if ($sugerido.Count -gt 0) { return $sugerido[0] }
    if ($Bancos.Count -eq 1) { return $Bancos[0] }

    Write-Host ''
    Write-Host ("[$Instancia] Selecione o banco:") -ForegroundColor Cyan
    for ($i = 0; $i -lt $Bancos.Count; $i++) {
        Write-Host (" [{0}] {1}" -f ($i + 1), $Bancos[$i])
    }
    $n = (Read-Host 'Numero do banco (ENTER para cancelar)').Trim()
    $indice = 0
    if (-not [int]::TryParse($n, [ref]$indice) -or $indice -lt 1 -or $indice -gt $Bancos.Count) {
        throw 'Banco nao selecionado. Nenhuma alteracao nesta instancia.'
    }
    return $Bancos[$indice - 1]
}

function Get-SenhaTextoNexusSql {
    param([Security.SecureString]$Senha)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Senha)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$senhaNova = $null
$sucessos = 0
$falhas = 0
try {
    Write-Host ''
    Write-Host 'CRIAR USUARIOS NO BANCO' -ForegroundColor Cyan
    $instancias = @(Get-InstanciasNexusSql)
    if ($instancias.Count -eq 0) { throw 'Nenhuma instancia SQL Server local acessivel foi encontrada.' }
    $sugestao = Get-BancoMaxIni
    Write-Host ('Instancias detectadas: ' + ($instancias -join ', '))

    foreach ($instancia in $instancias) {
        $conexao = $null
        try {
            $conexao = New-ConexaoNexusSql -Instancia $instancia -Timeout 5
            $conexao.Open()

            if ([int](Invoke-NexusSql -Conexao $conexao -Scalar -Sql "SELECT ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)") -ne 1) {
                throw 'Usuario Windows sem permissao sysadmin nesta instancia.'
            }

            $bancos = @(Get-BancosNexusSql -Conexao $conexao)
            $banco = Escolher-BancoNexusSql -Bancos $bancos -Sugestao $sugestao -Instancia $instancia
            if (-not $banco) { throw 'Nenhum banco de usuario disponivel.' }

            $loginExiste = [int](Invoke-NexusSql -Conexao $conexao -Scalar -Sql "SELECT COUNT(1) FROM sys.server_principals WHERE name = N'maxdata'")
            $criados = 0
            if ($loginExiste -eq 0) {
                if ($null -eq $senhaNova) {
                    $senhaNova = Read-Host 'Senha do novo login maxdata (uma unica vez)' -AsSecureString
                    if ($null -eq $senhaNova -or $senhaNova.Length -eq 0) { throw 'Senha nao informada.' }
                }
                $senhaTexto = Get-SenhaTextoNexusSql -Senha $senhaNova
                try {
                    Invoke-NexusSql -Conexao $conexao -Parametros @{Senha=$senhaTexto} -Sql @'
DECLARE @sql nvarchar(max) =
    N'CREATE LOGIN [maxdata] WITH PASSWORD = ' + NCHAR(39) +
    REPLACE(@Senha, NCHAR(39), NCHAR(39) + NCHAR(39)) + NCHAR(39) +
    N', DEFAULT_DATABASE = [master], DEFAULT_LANGUAGE = [Brazilian], CHECK_POLICY = ON, CHECK_EXPIRATION = OFF';
EXEC(@sql);
'@
                }
                finally { $senhaTexto = $null }
                $criados++
            }
            else {
                $tipo = [string](Invoke-NexusSql -Conexao $conexao -Scalar -Sql "SELECT type_desc FROM sys.server_principals WHERE name = N'maxdata'")
                if ($tipo -ne 'SQL_LOGIN') { throw "O principal maxdata existe, mas nao e login SQL ($tipo)." }
            }

            foreach ($role in $roles) {
                $existe = [int](Invoke-NexusSql -Conexao $conexao -Scalar -Parametros @{Role=$role} -Sql @'
SELECT COUNT(1) FROM sys.server_role_members r
JOIN sys.server_principals p ON p.principal_id = r.role_principal_id
JOIN sys.server_principals m ON m.principal_id = r.member_principal_id
WHERE p.name = @Role AND m.name = N'maxdata'
'@)
                if ($existe -eq 0) {
                    Invoke-NexusSql -Conexao $conexao -Sql ("ALTER SERVER ROLE [$role] ADD MEMBER [maxdata]")
                    $criados++
                }
            }

            $conexao.ChangeDatabase($banco)
            $usuarioExiste = [int](Invoke-NexusSql -Conexao $conexao -Scalar -Sql "SELECT COUNT(1) FROM sys.database_principals WHERE name = N'maxdata'")
            $usuarioMapeado = [int](Invoke-NexusSql -Conexao $conexao -Scalar -Sql "SELECT COUNT(1) FROM sys.database_principals WHERE name = N'maxdata' AND sid = SUSER_SID(N'maxdata')")
            if ($usuarioExiste -eq 0) {
                $outroMapeamento = [int](Invoke-NexusSql -Conexao $conexao -Scalar -Sql "SELECT COUNT(1) FROM sys.database_principals WHERE sid = SUSER_SID(N'maxdata')")
                if ($outroMapeamento -gt 0) { throw 'Login maxdata ja mapeado a outro usuario neste banco.' }
                Invoke-NexusSql -Conexao $conexao -Sql 'CREATE USER [maxdata] FOR LOGIN [maxdata] WITH DEFAULT_SCHEMA = [dbo]'
                $criados++
            }
            elseif ($usuarioMapeado -ne 1) {
                throw 'Usuario maxdata ja existe, mas mapeado a outro login.'
            }

            if ($criados -eq 0) {
                Write-Host "[$instancia | $banco] JA EXISTIA." -ForegroundColor Yellow
            } else {
                Write-Host "[$instancia | $banco] CONCLUIDO ($criados ajustes)." -ForegroundColor Green
            }
            $sucessos++
        }
        catch {
            $falhas++
            Write-Host ("[$instancia] FALHA: " + $_.Exception.Message) -ForegroundColor Red
        }
        finally {
            if ($null -ne $conexao) { $conexao.Dispose() }
        }
    }

    Write-Host ''
    Write-Host "Resultado: $sucessos instancia(s) concluida(s), $falhas com falha." -ForegroundColor Cyan
    if ($falhas -gt 0) { exit 1 }
}
catch {
    Write-Host ('FALHA: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally { $senhaNova = $null }
