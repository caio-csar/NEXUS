# =========================
# CONFIGURAÇÃO INICIAL
# =========================
$ErrorActionPreference = "Stop"

# Solicita apenas o nome do banco
$nomeBanco = Read-Host "Digite o nome do banco"

if ([string]::IsNullOrWhiteSpace($nomeBanco)) {
    Write-Host "Nome do banco inválido!" -ForegroundColor Red
    exit
}

$bancoAux = "${nomeBanco}_AUX"

Write-Host "Banco auxiliar será: $bancoAux" -ForegroundColor Cyan

# =========================
# LISTA DE INSTÂNCIAS PARA TESTE
# =========================
$instancias = @(
    "localhost",
    ".",
    "localhost\SQLEXPRESS",
    ".\SQLEXPRESS"
)

$instanciaValida = $null

Write-Host "Testando conexão com SQL Server..." -ForegroundColor Yellow

foreach ($inst in $instancias) {
    try {
        sqlcmd -S $inst -E -Q "SELECT 1" > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            $instanciaValida = $inst
            Write-Host "Conectado em: $inst" -ForegroundColor Green
            break
        }
    } catch {}
}

if (-not $instanciaValida) {
    Write-Host "Nenhuma instância de SQL Server encontrada!" -ForegroundColor Red
    exit
}

# =========================
# SCRIPT SQL
# =========================
$sql = @"
SET NOCOUNT ON;

DECLARE @BANCOAUX NVARCHAR(MAX) = '$bancoAux';
DECLARE @SQL NVARCHAR(MAX);

-- 1. Verifica se o banco existe
IF NOT EXISTS(SELECT * FROM sys.databases WHERE name = @BANCOAUX)
BEGIN
    SET @SQL = 'CREATE DATABASE ' + QUOTENAME(@BANCOAUX);
    EXEC (@SQL);
    PRINT 'Banco criado com sucesso.';
END
ELSE
BEGIN
    PRINT 'Banco já existe.';
END

-- 2. Cria tabela se não existir
SET @SQL = '
IF NOT EXISTS (SELECT * FROM ' + QUOTENAME(@BANCOAUX) + '.sys.tables WHERE name = ''dbaux_controleVersao'')
BEGIN
    CREATE TABLE ' + QUOTENAME(@BANCOAUX) + '.[dbo].[dbaux_controleVersao] (
        [exeId] INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        [exeNome] VARCHAR(50) NOT NULL,
        [exeVersao] VARCHAR(50) NOT NULL,
        [exeDataAlteracao] DATETIME DEFAULT GETDATE(),
        [exeArquivo] VARBINARY(MAX) NULL
    );
    PRINT ''Tabela criada com sucesso.'';
END
ELSE 
BEGIN 
    PRINT ''Tabela já existe.''; 
END';

EXEC (@SQL);
"@

# =========================
# EXECUÇÃO
# =========================
Write-Host "Executando script..." -ForegroundColor Yellow

sqlcmd -S $instanciaValida -E -d master -Q $sql

if ($LASTEXITCODE -eq 0) {
    Write-Host "Tudo certo! Script executado com sucesso." -ForegroundColor Green
} else {
    Write-Host "Erro na execução do script!" -ForegroundColor Red
}
