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

$PathAtual  = "/UTEIS"
$BaixouAlgo = $false

$destino = Selecionar-PastaNexus -Titulo "Selecione onde salvar os utilitarios"

if (-not $destino) {
    Mostrar-Aviso "Nenhuma pasta selecionada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

function Listar-Uteis {
    return @(Get-NexusCloudItemsComTipo -Cloud $Cloud -Path $PathAtual -Credencial $Cred)
}

while ($true) {
    Mostrar-TituloNexus "EXPLORAR UTILITARIOS"

    Write-Host "Caminho: $PathAtual" -ForegroundColor Cyan
    Write-Host ""

    $itens = Listar-Uteis

    Write-Host " 0 - Voltar"
    Write-Host ""

    for ($i = 0; $i -lt $itens.Count; $i++) {
        $tipo = if ($itens[$i].Tipo -eq "PASTA") { "[P]" } else { "[A]" }
        Write-Host (" {0} - {1} {2}" -f ($i + 1), $tipo, $itens[$i].Nome)
    }

    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    if ($op -eq "0") {
        if ($PathAtual -eq "/UTEIS") {
            break
        }
        else {
            $PathAtual = ($PathAtual -split "/")[0..(($PathAtual -split "/").Count - 2)] -join "/"
            if ([string]::IsNullOrWhiteSpace($PathAtual)) {
                $PathAtual = "/UTEIS"
            }
            continue
        }
    }

    if ($op -notmatch '^\d+$') {
        continue
    }

    $idx = [int]$op - 1

    if ($idx -lt 0 -or $idx -ge $itens.Count) {
        continue
    }

    $item = $itens[$idx]

    if ($item.Tipo -eq "PASTA") {
        $PathAtual = "$PathAtual/$($item.Nome)"
        continue
    }

    Mostrar-TituloNexus "DOWNLOAD UTILITARIO"

    Write-Host "Arquivo: $($item.Nome)" -ForegroundColor Cyan
    Write-Host "Destino: $destino" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirmar-Acao "Baixar arquivo")) {
        continue
    }

    $timer = Iniciar-TimerNexus

    $url   = "$Cloud$PathAtual/$($item.Nome)"
    $saida = Join-Path $destino $item.Nome

    if (Download-NexusArquivo -Url $url -Destino $saida -Nome $item.Nome -Headers $Headers) {
        Mostrar-Sucesso "Download concluido."
        $BaixouAlgo = $true
    }
    else {
        Mostrar-Erro "Falha no download."
    }

    Mostrar-TempoExecucao -Inicio $timer -Nome "download"
    Start-Sleep -Seconds 1
}

if ($BaixouAlgo) {
    Abrir-PastaNexus $destino
}

Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
