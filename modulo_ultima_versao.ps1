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

$Cloud   = "https://cloud.maxdata.com.br/remote.php/webdav"
$Cred    = Nova-CredencialNexus -Usuario $Usuario -SenhaPlain $SenhaPlain
$Headers = New-NexusBasicAuthHeader -Usuario $Cred.UserName -Credencial $Cred

Mostrar-TituloNexus "BAIXAR ULTIMA VERSAO"

$destino = Selecionar-PastaNexus -Titulo "Selecione onde salvar a ultima versao"

if (-not $destino) {
    Mostrar-Aviso "Nenhuma pasta selecionada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$base = "/VERSOES"

Write-Host "Buscando ultima versao disponivel..." -ForegroundColor Cyan

$series = @(Get-NexusSeries -Cloud $Cloud -Base $base -Credencial $Cred)

if ($series.Count -eq 0) {
    Mostrar-Erro "Nenhuma serie encontrada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$serie   = $series[-1].Nome
$versoes = @(Get-NexusVersoes -Cloud $Cloud -Path "$base/$serie" -Credencial $Cred)

if ($versoes.Count -eq 0) {
    Mostrar-Erro "Nenhuma versao encontrada na serie $serie."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$versao     = $versoes[-1].Nome
$pathVersao = "$base/$serie/$versao"

$arquivos = @(Get-NexusCloudItems -Cloud $Cloud -Path $pathVersao -Credencial $Cred)
$validos  = @(Get-NexusArquivosVersaoValidos -Arquivos $arquivos)

if ($validos.Count -eq 0) {
    Mostrar-Erro "Nenhum arquivo valido encontrado para a versao $versao."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

Write-Host ""
Write-Host "Serie: $serie" -ForegroundColor Cyan
Write-Host "Versao: $versao" -ForegroundColor Cyan
Write-Host "Destino: $destino" -ForegroundColor Cyan
Write-Host ""
Write-Host "Arquivos que serao baixados:" -ForegroundColor Cyan

foreach ($f in $validos) {
    Write-Host " - $f"
}

Write-Host ""

if (-not (Confirmar-Acao "Confirmar download")) {
    Mostrar-Aviso "Operacao cancelada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$timer = Iniciar-TimerNexus

$ProgressPreference = 'SilentlyContinue'

$ok   = 0
$erro = 0

foreach ($f in $validos) {
    $url   = "$Cloud$pathVersao/$f"
    $saida = Join-Path $destino $f

    if (Download-NexusArquivo -Url $url -Destino $saida -Nome $f -Headers $Headers) {
        $ok++
    }
    else {
        $erro++
    }
}

$ProgressPreference = 'Continue'

Write-Host ""
Mostrar-Sucesso "Download concluido."
Write-Host "Baixados: $ok" -ForegroundColor Green
Write-Host "Falhas: $erro" -ForegroundColor Yellow

Mostrar-TempoExecucao -Inicio $timer -Nome "download da ultima versao"
Abrir-PastaNexus $destino

Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
