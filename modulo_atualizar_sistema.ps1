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
$Cred  = Nova-CredencialNexus -Usuario $Usuario -SenhaPlain $SenhaPlain
$Headers = New-NexusBasicAuthHeader -Usuario $Cred.UserName -Credencial $Cred
$Base  = "/VERSOES"

function Escolher-SerieNexus {
    $series = @(Get-NexusSeries -Cloud $Cloud -Base $Base -Credencial $Cred)

    if ($series.Count -eq 0) {
        Mostrar-Erro "Nenhuma serie encontrada."
        return $null
    }

    Write-Host "Series disponiveis:" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $series.Count; $i++) {
        Write-Host " $($i + 1) - $($series[$i].Nome)"
    }

    Write-Host ""

    $op = (Read-Host "Escolha a serie").Trim()

    if ($op -notmatch '^\d+$') {
        return $null
    }

    $idx = [int]$op - 1

    if ($idx -lt 0 -or $idx -ge $series.Count) {
        return $null
    }

    return $series[$idx]
}

function Escolher-VersaoNexus {
    param($Serie)

    $versoes = @(Get-NexusVersoes -Cloud $Cloud -Path "$Base/$($Serie.Nome)" -Credencial $Cred)

    if ($versoes.Count -eq 0) {
        Mostrar-Erro "Nenhuma versao encontrada na serie $($Serie.Nome)."
        return $null
    }

    Write-Host ""
    Write-Host "Versoes disponiveis em $($Serie.Nome):" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $versoes.Count; $i++) {
        Write-Host " $($i + 1) - $($versoes[$i].Nome)"
    }

    Write-Host ""

    $op = (Read-Host "Escolha a versao").Trim()

    if ($op -notmatch '^\d+$') {
        return $null
    }

    $idx = [int]$op - 1

    if ($idx -lt 0 -or $idx -ge $versoes.Count) {
        return $null
    }

    return $versoes[$idx]
}

function Get-ArquivosValidosDaVersao {
    param(
        [string]$Serie,
        [string]$Versao
    )

    $path = "$Base/$Serie/$Versao"
    $arquivos = @(Get-NexusCloudItems -Cloud $Cloud -Path $path -Credencial $Cred)

    return @(Get-NexusArquivosVersaoValidos -Arquivos $arquivos)
}

function Atualizacao-Direta {
    Mostrar-TituloNexus "ATUALIZACAO DIRETA"

    $destino = Selecionar-PastaNexus -Titulo "Selecione onde salvar a atualizacao direta"

    if (-not $destino) {
        Mostrar-Aviso "Nenhuma pasta selecionada."
        return
    }

    $serie = Escolher-SerieNexus

    if (-not $serie) {
        Mostrar-Erro "Serie invalida."
        return
    }

    $versao = Escolher-VersaoNexus -Serie $serie

    if (-not $versao) {
        Mostrar-Erro "Versao invalida."
        return
    }

    $validos = @(Get-ArquivosValidosDaVersao -Serie $serie.Nome -Versao $versao.Nome)

    if ($validos.Count -eq 0) {
        Mostrar-Erro "Nenhum arquivo valido encontrado para esta versao."
        return
    }

    Write-Host ""
    Write-Host "Serie: $($serie.Nome)" -ForegroundColor Cyan
    Write-Host "Versao: $($versao.Nome)" -ForegroundColor Cyan
    Write-Host "Destino: $destino" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Arquivos que serao baixados:" -ForegroundColor Cyan

    foreach ($f in $validos) {
        Write-Host " - $f"
    }

    Write-Host ""

    if (-not (Confirmar-Acao "Confirmar download")) {
        Mostrar-Aviso "Operacao cancelada."
        return
    }

    $timer = Iniciar-TimerNexus
    $ProgressPreference = 'SilentlyContinue'

    $resultado = Invoke-NexusDownloadVersao `
        -Cloud $Cloud `
        -Base $Base `
        -Serie $serie.Nome `
        -Versao $versao.Nome `
        -Destino $destino `
        -Credencial $Cred `
        -Headers $Headers

    $ProgressPreference = 'Continue'

    Write-Host ""
    Mostrar-Sucesso "Atualizacao direta concluida."
    Write-Host "Baixados: $($resultado.OK)" -ForegroundColor Green
    Write-Host "Falhas: $($resultado.ERRO)" -ForegroundColor Yellow

    Mostrar-TempoExecucao -Inicio $timer -Nome "atualizacao direta"
    Abrir-PastaNexus $destino
}

function Atualizacao-Gradual {
    Mostrar-TituloNexus "ATUALIZACAO GRADUAL"

    $destino = Selecionar-PastaNexus -Titulo "Selecione onde salvar a atualizacao gradual"

    if (-not $destino) {
        Mostrar-Aviso "Nenhuma pasta selecionada."
        return
    }

    $series = @(Get-NexusSeries -Cloud $Cloud -Base $Base -Credencial $Cred)

    if ($series.Count -eq 0) {
        Mostrar-Erro "Nenhuma serie encontrada."
        return
    }

    $selecionados   = @()
    $ultimaEscolhida = $null

    foreach ($serie in $series) {
        Clear-Host
        Write-Host "========= ATUALIZACAO GRADUAL =========" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Serie: $($serie.Nome)" -ForegroundColor Cyan
        Write-Host ""

        $versoes = @(Get-NexusVersoes -Cloud $Cloud -Path "$Base/$($serie.Nome)" -Credencial $Cred)

        if ($versoes.Count -eq 0) {
            continue
        }

        for ($i = 0; $i -lt $versoes.Count; $i++) {
            Write-Host " $($i + 1) - $($versoes[$i].Nome)"
        }

        Write-Host ""
        $entrada = Read-Host @"
Selecione as versoes separando por virgula ou pressione ENTER para pular.

Exemplo: 1,7,3
"@

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
    Write-Host "========= RESUMO DA ATUALIZACAO GRADUAL =========" -ForegroundColor Cyan
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

    if (-not (Confirmar-Acao "Confirmar execucao da atualizacao gradual")) {
        Mostrar-Aviso "Operacao cancelada."
        return
    }

    $timer = Iniciar-TimerNexus
    $ProgressPreference = 'SilentlyContinue'

    $ok   = 0
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

        $ok   += $resultado.OK
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
            -Headers $Headers

        $ok   += $resultadoFinal.OK
        $erro += $resultadoFinal.ERRO
    }

    $ProgressPreference = 'Continue'

    Write-Host ""
    Mostrar-Sucesso "Atualizacao gradual concluida."
    Write-Host "Baixados: $ok" -ForegroundColor Green
    Write-Host "Falhas: $erro" -ForegroundColor Yellow

    Mostrar-TempoExecucao -Inicio $timer -Nome "atualizacao gradual"
    Abrir-PastaNexus $destino
}

while ($true) {
    Mostrar-TituloNexus "ATUALIZAR SISTEMA"

    Write-Host "1 - Atualizacao Direta"
    Write-Host "2 - Atualizacao Gradual"
    Write-Host "0 - Voltar"
    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    switch ($op) {
        "1" { Atualizacao-Direta;  Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore }
        "2" { Atualizacao-Gradual; Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore }
        "0" { return }
        default {
            Mostrar-Erro "Opcao invalida."
            Start-Sleep -Seconds 1
        }
    }
}
