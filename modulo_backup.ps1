param(
    [string]$Usuario,
    [string]$SenhaPlain,
    [int]$ChamadoPeloCore = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$shared = Join-Path $PSScriptRoot "NEXUS_SHARED.ps1"
if (Test-Path $shared) {
    . $shared
}
else {
    Write-Host "NEXUS_SHARED.ps1 nao encontrado." -ForegroundColor Red
    return
}

$Cred    = Nova-CredencialNexus -Usuario $Usuario -SenhaPlain $SenhaPlain
$Headers = New-NexusBasicAuthHeader -Usuario $Cred.UserName -Credencial $Cred

$WebDavUser       = $Cred.UserName
$CloudRoot        = "https://cloud.maxdata.com.br/remote.php/dav/files/$WebDavUser"
$PastaBackupWebDav = "$CloudRoot/nexus_backup"

function Test-SqlcmdNexus {
    $cmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
    return ($null -ne $cmd)
}

function Obter-BancosNexus {
    $dbs = sqlcmd `
        -Q "set nocount on;select name from sys.databases where database_id>4 order by name" `
        -h -1 -W 2>$null |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    return @($dbs)
}

function Selecionar-BancoNexus {
    $dbs = @(Obter-BancosNexus)

    if ($dbs.Count -eq 0) {
        Mostrar-Erro "Nenhum banco encontrado."
        return $null
    }

    Mostrar-TituloNexus "BACKUP PARA CLOUD"

    Write-Host "Bancos disponiveis:" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $dbs.Count; $i++) {
        Write-Host " $($i + 1) - $($dbs[$i])"
    }

    Write-Host ""

    $escolha = (Read-Host "Selecione o banco").Trim()

    if ($escolha -notmatch '^\d+$') {
        return $null
    }

    $idx = [int]$escolha - 1

    if ($idx -lt 0 -or $idx -ge $dbs.Count) {
        return $null
    }

    return $dbs[$idx].Trim()
}

Mostrar-TituloNexus "BACKUP PARA CLOUD"

if (-not (Test-SqlcmdNexus)) {
    Mostrar-Erro "sqlcmd nao encontrado no ambiente."
    Mostrar-Aviso "Instale as ferramentas do SQL Server ou execute em um ambiente com sqlcmd disponivel."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$db = Selecionar-BancoNexus

if (-not $db) {
    Mostrar-Erro "Banco invalido ou nao selecionado."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$pastaLocal = Selecionar-PastaNexus -Titulo "Selecione a pasta temporaria para gerar o backup"

if (-not $pastaLocal) {
    Mostrar-Aviso "Nenhuma pasta selecionada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$bak   = Join-Path $pastaLocal "$db`_$stamp.bak"
$zip   = Join-Path $pastaLocal "$db`_$stamp.zip"

Mostrar-TituloNexus "BACKUP PARA CLOUD"

Write-Host "Banco: $db" -ForegroundColor Cyan
Write-Host "Pasta temporaria: $pastaLocal" -ForegroundColor Cyan
Write-Host "Destino WebDAV: nexus_backup" -ForegroundColor Cyan
Write-Host ""
Write-Host "Apos o upload, o .BAK e o .ZIP local serao apagados." -ForegroundColor Yellow
Write-Host ""

if (-not (Confirmar-Acao "Confirmar backup")) {
    Mostrar-Aviso "Operacao cancelada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$timer = Iniciar-TimerNexus

try {
    Mostrar-TituloNexus "BACKUP PARA CLOUD"

    Write-Host "Gerando backup..." -ForegroundColor Cyan

    sqlcmd `
        -Q "BACKUP DATABASE [$db] TO DISK=N'$bak' WITH INIT" `
        -b

    if (-not (Test-Path $bak)) {
        throw "Arquivo .bak nao foi gerado."
    }

    Write-Host "Compactando backup..." -ForegroundColor Cyan

    Compress-Archive `
        -Path $bak `
        -DestinationPath $zip `
        -Force `
        -ErrorAction Stop

    if (-not (Test-Path $zip)) {
        throw "Arquivo .zip nao foi gerado."
    }

    Write-Host "Garantindo pasta no WebDAV..." -ForegroundColor Cyan
    Criar-PastaWebDav -Url $PastaBackupWebDav -Headers $Headers | Out-Null

    $nomeZip  = Split-Path $zip -Leaf
    $nomeUrl  = [System.Uri]::EscapeDataString($nomeZip)
    $urlUpload = "$PastaBackupWebDav/$nomeUrl"

    Write-Host "Enviando backup para cloud..." -ForegroundColor Cyan

    $enviado = Upload-NexusArquivo `
        -Url $urlUpload `
        -Arquivo $zip `
        -Nome $nomeZip `
        -Headers $Headers

    if (-not $enviado) {
        throw "Falha no upload do backup."
    }

    Write-Host ""
    Mostrar-Sucesso "Backup enviado com sucesso."
}
catch {
    Write-Host ""
    Mostrar-Erro "Falha no backup."
    Mostrar-Detalhe $_.Exception.Message
}
finally {
    if (Test-Path $bak) {
        Remove-Item $bak -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $zip) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    Mostrar-TempoExecucao -Inicio $timer -Nome "backup para cloud"
}

Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
