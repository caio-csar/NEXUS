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

$Cloud = "https://cloud.maxdata.com.br/remote.php/webdav"
$Cred = Nova-CredencialNexus -Usuario $Usuario -SenhaPlain $SenhaPlain
$Headers = New-NexusBasicAuthHeader -Usuario $Cred.UserName -Credencial $Cred
$Base = "/VERSOES"

function Atualizacao-Nexus {
    Mostrar-TituloNexus "ATUALIZACAO"

    $destino = Selecionar-PastaNexus -Titulo "Selecione onde salvar a atualizacao"

    if (-not $destino) {
        Mostrar-Aviso "Nenhuma pasta selecionada."
        return
    }

    $series = @(Get-NexusSeries -Cloud $Cloud -Base $Base -Credencial $Cred)

    if ($series.Count -eq 0) {
        Mostrar-Erro "Nenhuma serie encontrada."
        return
    }

    $selecionados = @()
    $ultimaEscolhida = $null

    foreach ($serie in $series) {
        Clear-Host

        Write-Host ""
        Write-Host "===== ATUALIZACAO =====" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "Selecione a(s) versao(oes) desejada(s)." -ForegroundColor White
        Write-Host "Exemplo: 1,3,7" -ForegroundColor Green
        Write-Host "0 = voltar" -ForegroundColor Green

        Write-Host ""
        Write-Host "Serie $($serie.Nome) [ENTER = pular serie]" -ForegroundColor Yellow
        Write-Host ""

        $versoes = @(Get-NexusVersoes -Cloud $Cloud -Path "$Base/$($serie.Nome)" -Credencial $Cred)

        if ($versoes.Count -eq 0) {
            Write-Host " Nenhuma versao encontrada." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            continue
        }

        for ($i = 0; $i -lt $versoes.Count; $i++) {
            Write-Host " $($i + 1) - $($versoes[$i].Nome)"
        }

        Write-Host ""

        $entrada = (Read-Host "Escolha").Trim()

        if ($entrada -eq "0") {
            return
        }

        if ([string]::IsNullOrWhiteSpace($entrada)) {
            continue
        }

        $selecoesSerie = @(Interpretar-SelecaoNumericaNexus -Texto $entrada -Itens $versoes)

        foreach ($v in $selecoesSerie) {
            $selecionados += [PSCustomObject]@{
                Serie = $serie.Nome
                Versao = $v.Nome
            }

            $ultimaEscolhida = [PSCustomObject]@{
                Serie = $serie.Nome
                Versao = $v.Nome
            }
        }
    }

    if ($selecionados.Count -eq 0) {
        Mostrar-Aviso "Nenhuma versao selecionada."
        return
    }

    Clear-Host

    Write-Host ""
    Write-Host "===== RESUMO DA ATUALIZACAO =====" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Destino: $destino" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Versoes selecionadas:" -ForegroundColor Cyan

    foreach ($item in $selecionados) {
        Write-Host " - $($item.Serie) / $($item.Versao)"
    }

    Write-Host ""

    $baixarCompleta = Confirmar-Acao "Deseja baixar tambem a versao completa da ultima versao selecionada ($($ultimaEscolhida.Versao))?"

    Write-Host ""

    if (-not (Confirmar-Acao "Confirmar atualizacao")) {
        Mostrar-Aviso "Operacao cancelada."
        return
    }

    $timer = Iniciar-TimerNexus

    $ProgressPreference = 'SilentlyContinue'

    $ok = 0
    $erro = 0

    foreach ($item in $selecionados) {
        $resultado = Invoke-NexusDownloadVersao `
            -Cloud $Cloud `
            -Base $Base `
            -Serie $item.Serie `
            -Versao $item.Versao `
            -Destino $destino `
            -Credencial $Cred `
            -Headers $Headers

        $ok += $resultado.OK
        $erro += $resultado.ERRO
    }

    if ($baixarCompleta) {
        $resultadoFinal = Invoke-NexusDownloadVersao `
            -Cloud $Cloud `
            -Base $Base `
            -Serie $ultimaEscolhida.Serie `
            -Versao $ultimaEscolhida.Versao `
            -Destino $destino `
            -Credencial $Cred `
            -Headers $Headers `
            -Completo

        $ok += $resultadoFinal.OK
        $erro += $resultadoFinal.ERRO
    }

    $ProgressPreference = 'Continue'

    Write-Host ""
    Mostrar-Sucesso "Atualizacao concluida."
    Write-Host "Baixados: $ok" -ForegroundColor Green
    Write-Host "Falhas: $erro" -ForegroundColor Yellow

    Mostrar-TempoExecucao -Inicio $timer -Nome "atualizacao"
    Abrir-PastaNexus $destino
}

Atualizacao-Nexus

Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore