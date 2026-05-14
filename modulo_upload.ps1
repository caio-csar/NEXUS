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

$WebDavUser  = $Cred.UserName
$CloudRoot   = "https://cloud.maxdata.com.br/remote.php/dav/files/$WebDavUser"
$PastaWebDav = "$CloudRoot/nexus_upload"

function Garantir-Pasta-Transfer {
    Criar-PastaWebDav -Url $PastaWebDav -Headers $Headers | Out-Null
}

function Formatar-TamanhoNexus {
    param([int64]$Bytes)

    if ($Bytes -ge 1GB) {
        return ("{0:N2} GB" -f ($Bytes / 1GB))
    }

    if ($Bytes -ge 1MB) {
        return ("{0:N2} MB" -f ($Bytes / 1MB))
    }

    if ($Bytes -ge 1KB) {
        return ("{0:N2} KB" -f ($Bytes / 1KB))
    }

    return "$Bytes B"
}

function Selecionar-ItensUpload {
    while ($true) {
        Mostrar-TituloNexus "UPLOAD"

        Write-Host "1 - Arquivo(s)"
        Write-Host "2 - Pasta compactada em ZIP"
        Write-Host "0 - Voltar"
        Write-Host ""

        $tipo = (Read-Host "Escolha").Trim()

        if ($tipo -eq "0") {
            return @()
        }

        if ($tipo -eq "1") {
            $arquivos = @(Selecionar-ArquivoNexus `
                -Titulo "Selecione um ou mais arquivos para enviar" `
                -Filtro "Todos os arquivos (*.*)|*.*" `
                -Multiselect)

            $lista = @()

            foreach ($arquivo in $arquivos) {
                if (Test-Path $arquivo) {
                    $lista += [PSCustomObject]@{
                        Caminho    = $arquivo
                        Nome       = Split-Path $arquivo -Leaf
                        Temporario = $false
                    }
                }
            }

            return $lista
        }

        if ($tipo -eq "2") {
            $pasta = Selecionar-PastaNexus -Titulo "Selecione a pasta para compactar e enviar"

            if (-not $pasta) {
                Mostrar-Aviso "Nenhuma pasta selecionada."
                Start-Sleep -Seconds 1
                return @()
            }

            $nomePasta = Split-Path $pasta -Leaf
            $data      = Get-Date -Format "yyyyMMdd_HHmmss"
            $zip       = Join-Path $env:TEMP "$nomePasta`_$data.zip"

            Write-Host ""
            Write-Host "Compactando pasta..." -ForegroundColor Cyan

            try {
                Compress-Archive `
                    -Path (Join-Path $pasta "*") `
                    -DestinationPath $zip `
                    -Force `
                    -ErrorAction Stop
            }
            catch {
                Mostrar-Erro "Erro ao compactar pasta."
                Mostrar-Detalhe $_.Exception.Message
                return @()
            }

            if (-not (Test-Path $zip)) {
                Mostrar-Erro "Erro ao criar ZIP temporario."
                return @()
            }

            return @(
                [PSCustomObject]@{
                    Caminho    = $zip
                    Nome       = Split-Path $zip -Leaf
                    Temporario = $true
                }
            )
        }

        Mostrar-Erro "Opcao invalida."
        Start-Sleep -Seconds 1
    }
}

function Fazer-UploadTransfer {
    Garantir-Pasta-Transfer

    $itens = @(Selecionar-ItensUpload)

    if ($itens.Count -eq 0) {
        return
    }

    Mostrar-TituloNexus "UPLOAD"

    Write-Host "Destino WebDAV: nexus_upload" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Itens selecionados:" -ForegroundColor Cyan

    foreach ($item in $itens) {
        Write-Host " - $($item.Nome)"
    }

    Write-Host ""

    if (-not (Confirmar-Acao "Confirmar upload")) {
        foreach ($item in $itens) {
            if ($item.Temporario -eq $true -and (Test-Path $item.Caminho)) {
                Remove-Item $item.Caminho -Force -ErrorAction SilentlyContinue
            }
        }

        Mostrar-Aviso "Operacao cancelada."
        return
    }

    $timer = Iniciar-TimerNexus

    Mostrar-TituloNexus "UPLOAD"

    $ok   = 0
    $erro = 0

    foreach ($item in $itens) {
        $nomeUrl = [System.Uri]::EscapeDataString($item.Nome)
        $url     = "$PastaWebDav/$nomeUrl"

        if (Upload-NexusArquivo -Url $url -Arquivo $item.Caminho -Nome $item.Nome -Headers $Headers) {
            $ok++
        }
        else {
            $erro++
        }

        if ($item.Temporario -eq $true -and (Test-Path $item.Caminho)) {
            Remove-Item $item.Caminho -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Mostrar-Sucesso "Upload concluido."
    Write-Host "Enviados: $ok" -ForegroundColor Green
    Write-Host "Falhas: $erro" -ForegroundColor Yellow

    Mostrar-TempoExecucao -Inicio $timer -Nome "upload"
}

function Obter-ArquivosTransfer {
    Garantir-Pasta-Transfer

    $body = @"
<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:resourcetype/>
    <d:getcontentlength/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>
"@

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    $req = [System.Net.HttpWebRequest]::Create($PastaWebDav)
    $req.Method = "PROPFIND"
    $req.Headers.Add("Authorization", $Headers.Authorization)
    $req.Headers.Add("Depth", "1")
    $req.ContentType = "text/xml"
    $req.ContentLength = $bytes.Length

    $stream = $req.GetRequestStream()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Close()

    $resp   = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $content = $reader.ReadToEnd()

    $reader.Close()
    $resp.Close()

    [xml]$xml = $content

    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace("d", "DAV:")

    $responses = $xml.SelectNodes("//d:response", $ns)
    $lista = @()

    foreach ($r in $responses) {
        $hrefNode = $r.SelectSingleNode("d:href", $ns)

        if ($null -eq $hrefNode) {
            continue
        }

        $href         = [System.Uri]::UnescapeDataString($hrefNode.InnerText)
        $hrefSemBarra = $href.TrimEnd("/")
        $pastaAtual   = "/remote.php/dav/files/$WebDavUser/nexus_upload"

        if ($hrefSemBarra -eq $pastaAtual) {
            continue
        }

        $isFolder = $r.SelectSingleNode("d:propstat/d:prop/d:resourcetype/d:collection", $ns)

        if ($null -ne $isFolder) {
            continue
        }

        $nome = Split-Path $href -Leaf

        if ([string]::IsNullOrWhiteSpace($nome)) {
            continue
        }

        $tamanhoNode = $r.SelectSingleNode("d:propstat/d:prop/d:getcontentlength", $ns)

        $lista += [PSCustomObject]@{
            Nome     = $nome
            Tamanho  = if ($tamanhoNode) { [int64]$tamanhoNode.InnerText } else { 0 }
        }
    }

    return @($lista | Sort-Object Nome)
}

function Mostrar-MenuDownloadTransfer {
    param([array]$Arquivos)

    Mostrar-TituloNexus "DOWNLOAD"

    Write-Host "Pasta WebDAV: nexus_upload"
    Write-Host ""
    Write-Host "Arquivos disponiveis:"
    Write-Host ""

    if ($Arquivos.Count -eq 0) {
        Write-Host " Nenhum arquivo encontrado." -ForegroundColor Yellow
    }
    else {
        for ($i = 0; $i -lt $Arquivos.Count; $i++) {
            $n    = $i + 1
            $nome = $Arquivos[$i].Nome
            $tam  = Formatar-TamanhoNexus -Bytes $Arquivos[$i].Tamanho

            $linha = (" [{0}] {1}" -f $n, $nome).PadRight(60)
            Write-Host "$linha $tam"
        }
    }

    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host ""
    Write-Host "Digite uma opcao:"
    Write-Host "- Um arquivo: 1"
    Write-Host "- Varios arquivos: 1,3,4"
    Write-Host "- Atualizar lista: R"
    Write-Host "- Voltar: 0"
    Write-Host ""
}

function Baixar-ArquivosTransfer {
    param([array]$Arquivos)

    if ($Arquivos.Count -eq 0) {
        return
    }

    $destinoPasta = Selecionar-PastaNexus -Titulo "Selecione onde salvar os arquivos baixados"

    if (-not $destinoPasta) {
        Mostrar-Aviso "Nenhuma pasta selecionada."
        return
    }

    Mostrar-TituloNexus "DOWNLOAD"

    Write-Host "Destino: $destinoPasta" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Arquivos selecionados:" -ForegroundColor Cyan

    foreach ($arquivo in $Arquivos) {
        Write-Host " - $($arquivo.Nome)"
    }

    Write-Host ""

    if (-not (Confirmar-Acao "Confirmar download")) {
        Mostrar-Aviso "Operacao cancelada."
        return
    }

    $timer = Iniciar-TimerNexus

    Mostrar-TituloNexus "DOWNLOAD"

    $ok   = 0
    $erro = 0

    foreach ($arquivo in $Arquivos) {
        $destino = Join-Path $destinoPasta $arquivo.Nome
        $nomeUrl = [System.Uri]::EscapeDataString($arquivo.Nome)
        $url     = "$PastaWebDav/$nomeUrl"

        if (Download-NexusArquivo -Url $url -Destino $destino -Nome $arquivo.Nome -Headers $Headers) {
            $ok++
        }
        else {
            $erro++
        }
    }

    Write-Host ""
    Mostrar-Sucesso "Download concluido."
    Write-Host "Baixados: $ok" -ForegroundColor Green
    Write-Host "Falhas: $erro" -ForegroundColor Yellow

    Mostrar-TempoExecucao -Inicio $timer -Nome "download"
    Abrir-PastaNexus $destinoPasta
}

function Fazer-DownloadTransfer {
    while ($true) {
        try {
            $arquivos = @(Obter-ArquivosTransfer)
        }
        catch {
            Mostrar-TituloNexus "DOWNLOAD"
            Mostrar-Erro "Erro ao consultar WebDAV."
            Mostrar-Detalhe $_.Exception.Message
            Write-Host ""
            Write-Host "R - Tentar novamente"
            Write-Host "0 - Voltar"
            Write-Host ""

            $erroOp = (Read-Host "Escolha").Trim().ToUpper()

            if ($erroOp -eq "0") {
                return
            }

            continue
        }

        Mostrar-MenuDownloadTransfer -Arquivos $arquivos

        $input = (Read-Host "Escolha").Trim()

        if ([string]::IsNullOrWhiteSpace($input)) {
            continue
        }

        if ($input.ToUpper() -eq "R") {
            continue
        }

        if ($input -eq "0") {
            return
        }

        $selecionados = @(Interpretar-SelecaoNumericaNexus -Texto $input -Itens $arquivos)

        if ($selecionados.Count -eq 0) {
            Mostrar-Erro "Nenhum arquivo valido selecionado."
            Start-Sleep -Seconds 1
            continue
        }

        Baixar-ArquivosTransfer -Arquivos $selecionados
    }
}

while ($true) {
    Mostrar-TituloNexus "NEXUS TRANSFER"

    Write-Host "1 - Upload"
    Write-Host "2 - Download"
    Write-Host "0 - Voltar"
    Write-Host ""

    $opcao = (Read-Host "Escolha").Trim()

    switch ($opcao) {
        "1" {
            Fazer-UploadTransfer
            Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
        }
        "2" {
            Fazer-DownloadTransfer
        }
        "0" {
            return
        }
        default {
            Mostrar-Erro "Opcao invalida."
            Start-Sleep -Seconds 1
        }
    }
}
