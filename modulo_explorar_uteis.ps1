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

$script:Cloud = "https://cloud.maxdata.com.br/remote.php/webdav"
$script:NexusRawBase = "https://raw.githubusercontent.com/caio-csar/NEXUS/main"
$script:Cred = Nova-CredencialNexus -Usuario $Usuario -SenhaPlain $SenhaPlain
$script:Headers = New-NexusBasicAuthHeader -Usuario $script:Cred.UserName -Credencial $script:Cred

function Baixar-ArquivoPublicoUtilitario {
    param(
        [string]$Caminho,
        [string]$Destino,
        [string]$Nome
    )

    $url = "$script:NexusRawBase/$Caminho"

    try {
        Invoke-WebRequest `
            -Uri $url `
            -OutFile $Destino `
            -UseBasicParsing `
            -ErrorAction Stop

        return (Test-Path $Destino)
    }
    catch {
        Mostrar-Erro "Falha ao baixar $Nome."
        Mostrar-Detalhe $_.Exception.Message
        return $false
    }
}

function Corrigir-WmiNexus {
    Mostrar-TituloNexus "CORRIGIR WMI"

    if (-not (Confirmar-Acao "Executar correcao WMI")) {
        return
    }

    $bat = Join-Path $env:TEMP "nexus_wmi_reset.bat"

    if (-not (Baixar-ArquivoPublicoUtilitario -Caminho "Scripts_Uteis/wmi_reset.bat" -Destino $bat -Nome "Corrigir WMI")) {
        return
    }

    try {
        Start-Process -FilePath $bat -WorkingDirectory (Split-Path $bat -Parent) -Wait
        Mostrar-Sucesso "Correcao WMI finalizada."
    }
    catch {
        Mostrar-Erro "Falha ao executar correcao WMI."
        Mostrar-Detalhe $_.Exception.Message
    }
}

function Instalar-VerificarOdbcNexus {
    Mostrar-TituloNexus "INSTALAR/VERIFICAR ODBC"

    $modulo = Join-Path $env:TEMP "modulo_testar_odbc.ps1"

    if (-not (Baixar-ArquivoPublicoUtilitario -Caminho "modulo_testar_odbc.ps1" -Destino $modulo -Nome "Modulo ODBC")) {
        return
    }

    try {
        powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $modulo `
            -Usuario $Usuario `
            -SenhaPlain $SenhaPlain `
            -ChamadoPeloCore 1
    }
    catch {
        Mostrar-Erro "Falha ao executar modulo ODBC."
        Mostrar-Detalhe $_.Exception.Message
    }
    finally {
        Remove-Item -LiteralPath $modulo -Force -ErrorAction SilentlyContinue
    }
}

function Abrir-PastaSistemaNexus {
    Mostrar-TituloNexus "ABRIR PASTA DO SISTEMA"

    $pasta = Selecionar-PastaNexus -Titulo "Selecione a pasta do sistema"
    if (-not $pasta) {
        Mostrar-Aviso "Nenhuma pasta selecionada."
        return
    }

    Abrir-PastaNexus $pasta
}

function Explorar-ArquivosUteisNexus {
    $pathAtual = "/UTEIS"
    $baixouAlgo = $false

    $destino = Selecionar-PastaNexus -Titulo "Selecione onde salvar os utilitarios"

    if (-not $destino) {
        Mostrar-Aviso "Nenhuma pasta selecionada."
        return
    }

    while ($true) {
        Mostrar-TituloNexus "EXPLORAR ARQUIVOS UTEIS"

        Write-Host "Caminho: $pathAtual" -ForegroundColor Cyan
        Write-Host ""

        $itens = @(Get-NexusCloudItemsComTipo -Cloud $script:Cloud -Path $pathAtual -Credencial $script:Cred)

        Write-Host " 0 - Voltar"
        Write-Host ""

        for ($i = 0; $i -lt $itens.Count; $i++) {
            $tipo = if ($itens[$i].Tipo -eq "PASTA") { "[P]" } else { "[A]" }
            Write-Host (" {0} - {1} {2}" -f ($i + 1), $tipo, $itens[$i].Nome)
        }

        Write-Host ""

        $op = (Read-Host "Escolha").Trim()

        if ($op -eq "0") {
            if ($pathAtual -eq "/UTEIS") {
                break
            }

            $partes = @($pathAtual -split "/" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($partes.Count -le 1) {
                $pathAtual = "/UTEIS"
            }
            else {
                $pathAtual = "/" + (($partes[0..($partes.Count - 2)]) -join "/")
            }

            continue
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
            $pathAtual = "$pathAtual/$($item.Nome)"
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

        $url = "$script:Cloud$pathAtual/$($item.Nome)"
        $saida = Join-Path $destino $item.Nome

        if (Download-NexusArquivo -Url $url -Destino $saida -Nome $item.Nome -Headers $script:Headers) {
            Mostrar-Sucesso "Download concluido."
            $baixouAlgo = $true
        }
        else {
            Mostrar-Erro "Falha no download."
        }

        Mostrar-TempoExecucao -Inicio $timer -Nome "download"
        Start-Sleep -Seconds 1
    }

    if ($baixouAlgo) {
        Abrir-PastaNexus $destino
    }
}

while ($true) {
    Mostrar-TituloNexus "UTILITARIOS"

    Write-Host "1 - Corrigir WMI"
    Write-Host "2 - Instalar/Verificar ODBC"
    Write-Host "3 - Abrir Pasta do Sistema"
    Write-Host "4 - Explorar Arquivos Uteis"
    Write-Host "0 - Voltar"
    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    switch ($op) {
        "1" { Corrigir-WmiNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "2" { Instalar-VerificarOdbcNexus }
        "3" { Abrir-PastaSistemaNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "4" { Explorar-ArquivosUteisNexus }
        "0" { break }
        default { continue }
    }
}
