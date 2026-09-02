# ============================================
# NEXUS SHARED
# ============================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:NexusProcessoInicioConfirmacao = $null
$script:NexusProcessoTempoMostrado = $false

# ============================================
# FUNCOES - INTERFACE
# ============================================

function Mostrar-TituloNexus {
    param([string]$Titulo)

    Clear-Host
    Write-Host "========= $Titulo =========" -ForegroundColor Cyan
    Write-Host ""
}

function Mostrar-Sucesso {
    param([string]$Mensagem)

    Write-Host $Mensagem -ForegroundColor Green
}

function Mostrar-Erro {
    param([string]$Mensagem)

    Write-Host $Mensagem -ForegroundColor Red
}

function Mostrar-Aviso {
    param([string]$Mensagem)

    Write-Host $Mensagem -ForegroundColor Yellow
}

function Mostrar-Detalhe {
    param([string]$Mensagem)

    Write-Host $Mensagem -ForegroundColor DarkGray
}

function Pausar-Nexus {
    param([int]$ChamadoPeloCore = 0)

    Mostrar-TempoDesdeConfirmacaoNexus

    if ($ChamadoPeloCore -ne 1) {
        Read-Host "`nPressione ENTER para continuar"
    }
}

function Confirmar-Acao {
    param(
        [string]$Mensagem = "Deseja continuar?"
    )

    $resp = (Read-Host "$Mensagem (S/N)").Trim().ToUpper()

    if ($resp -eq "S") {
        Iniciar-TempoConfirmacaoNexus
        return $true
    }

    return $false
}

# ============================================
# FUNCOES - DIRETORIOS / ARQUIVOS
# ============================================

function Get-PastaMaxPadrao {
    try {
        $pastaMax = Get-ChildItem "C:\" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq "MAX" } |
            Select-Object -First 1

        if ($pastaMax) {
            return $pastaMax.FullName
        }

        if (Test-Path "C:\") {
            return "C:\"
        }
    }
    catch {}

    return $null
}

function Selecionar-PastaNexus {
    param(
        [string]$Titulo = "Selecione uma pasta"
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop

        $padrao = Get-PastaMaxPadrao

        if ([string]::IsNullOrWhiteSpace($padrao)) {
            $padrao = "C:\"
        }

        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = $Titulo
        $dialog.InitialDirectory = $padrao
        $dialog.ValidateNames = $false
        $dialog.CheckFileExists = $false
        $dialog.CheckPathExists = $true
        $dialog.FileName = "Selecionar esta pasta"

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return Split-Path $dialog.FileName
        }

        return $null
    }
    catch {
        Mostrar-Aviso "Falha ao abrir janela grafica."
    }

    $manual = Read-Host "Informe o caminho manualmente"

    if ([string]::IsNullOrWhiteSpace($manual)) {
        return $null
    }

    if (-not (Test-Path $manual)) {
        try {
            New-Item -ItemType Directory -Path $manual -Force | Out-Null
        }
        catch {
            Mostrar-Erro "Nao foi possivel criar/acessar o caminho informado."
            return $null
        }
    }

    return $manual
}

function Selecionar-ArquivoNexus {
    param(
        [string]$Titulo = "Selecione um arquivo",
        [string]$Filtro = "Todos os arquivos (*.*)|*.*",
        [switch]$Multiselect
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop

        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = $Titulo
        $dialog.Filter = $Filtro
        $dialog.Multiselect = [bool]$Multiselect

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if ($Multiselect) {
                return $dialog.FileNames
            }

            return $dialog.FileName
        }
    }
    catch {
        Mostrar-Aviso "Falha ao abrir janela grafica."
    }

    $manual = Read-Host "Informe o caminho do arquivo manualmente"

    if ([string]::IsNullOrWhiteSpace($manual)) {
        return $null
    }

    return $manual
}

function Abrir-PastaNexus {
    param([string]$Caminho)

    if ([string]::IsNullOrWhiteSpace($Caminho)) {
        return
    }

    if (Test-Path $Caminho) {
        Start-Process explorer.exe $Caminho
    }
}

# ============================================
# FUNCOES - TIMER
# ============================================

function Iniciar-TimerNexus {
    return Get-Date
}

function Iniciar-TempoConfirmacaoNexus {
    $script:NexusProcessoInicioConfirmacao = Get-Date
    $script:NexusProcessoTempoMostrado = $false
}

function Limpar-TempoConfirmacaoNexus {
    $script:NexusProcessoInicioConfirmacao = $null
    $script:NexusProcessoTempoMostrado = $false
}

function Mostrar-TempoDesdeConfirmacaoNexus {
    param(
        [string]$Nome = "processo"
    )

    if (-not $script:NexusProcessoInicioConfirmacao) {
        return
    }

    if ($script:NexusProcessoTempoMostrado) {
        return
    }

    $tempo = (Get-Date) - $script:NexusProcessoInicioConfirmacao
    Write-Host ""
    Write-Host "Tempo desde confirmacao ($Nome): $($tempo.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

    $script:NexusProcessoTempoMostrado = $true
}

function Mostrar-TempoExecucao {
    param(
        [datetime]$Inicio,
        [string]$Nome = "processo"
    )

    $tempo = (Get-Date) - $Inicio
    Write-Host ""
    $rotulo = if ($script:NexusProcessoInicioConfirmacao) { "Tempo desde confirmacao" } else { "Tempo de execucao" }
    Write-Host "$rotulo ($Nome): $($tempo.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

    if ($script:NexusProcessoInicioConfirmacao) {
        $script:NexusProcessoTempoMostrado = $true
    }
}

# ============================================
# FUNCOES - CREDENCIAL
# ============================================

function Nova-CredencialNexus {
    param(
        [string]$Usuario,
        [string]$SenhaPlain
    )

    if ([string]::IsNullOrWhiteSpace($Usuario)) {
        $Usuario = Read-Host "Usuario"
    }

    if ([string]::IsNullOrWhiteSpace($SenhaPlain)) {
        $Senha = Read-Host "Senha" -AsSecureString
    }
    else {
        $Senha = ConvertTo-SecureString $SenhaPlain -AsPlainText -Force
    }

    return New-Object System.Management.Automation.PSCredential($Usuario, $Senha)
}

function New-NexusBasicAuthHeader {
    param(
        [string]$Usuario,
        [string]$SenhaPlain,
        [System.Management.Automation.PSCredential]$Credencial
    )

    if ([string]::IsNullOrWhiteSpace($SenhaPlain) -and $Credencial) {
        $SenhaPlain = $Credencial.GetNetworkCredential().Password
    }

    if ([string]::IsNullOrWhiteSpace($Usuario) -and $Credencial) {
        $Usuario = $Credencial.UserName
    }

    $basic = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes("${Usuario}:${SenhaPlain}")
    )

    return @{
        Authorization = "Basic $basic"
    }
}

# ============================================
# FUNCOES - WEBDAV
# ============================================

function Get-NexusCloudItems {
    param(
        [string]$Cloud,
        [string]$Path,
        [System.Management.Automation.PSCredential]$Credencial
    )

    $url = "$Cloud$Path"
    $body = '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>'

    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Method = "PROPFIND"
        $req.Headers.Add("Depth", "1")
        $req.Credentials = $Credencial
        $req.ContentType = "text/xml"

        $stream = $req.GetRequestStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.Write($body)
        $writer.Close()

        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $xml = [xml]$reader.ReadToEnd()

        $reader.Close()
        $resp.Close()

        $items = @()

        $xml.multistatus.response |
            Select-Object -Skip 1 |
            ForEach-Object {
                $nome = $_.propstat.prop.displayname
                if ($nome) {
                    $items += $nome
                }
            }

        return $items
    }
    catch {
        Mostrar-Erro "Erro ao acessar: $Path"
        Mostrar-Detalhe $_.Exception.Message
        return @()
    }
}

function Get-NexusCloudItemsComTipo {
    param(
        [string]$Cloud,
        [string]$Path,
        [System.Management.Automation.PSCredential]$Credencial
    )

    $url = "$Cloud$Path"
    $body = '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/><d:resourcetype/></d:prop></d:propfind>'

    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Method = "PROPFIND"
        $req.Headers.Add("Depth", "1")
        $req.Credentials = $Credencial
        $req.ContentType = "text/xml"

        $stream = $req.GetRequestStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.Write($body)
        $writer.Close()

        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $xml = [xml]$reader.ReadToEnd()

        $reader.Close()
        $resp.Close()

        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace("d", "DAV:")

        $items = @()

        $xml.multistatus.response |
            Select-Object -Skip 1 |
            ForEach-Object {
                $nome = $_.propstat.prop.displayname

                # Usa SelectSingleNode com namespace para detectar pastas corretamente.
                # O elemento <d:collection/> e vazio — sem namespace manager retornaria
                # string vazia em vez de $null, causando classificacao incorreta.
                $ehPasta = $null -ne $_.SelectSingleNode("d:propstat/d:prop/d:resourcetype/d:collection", $ns)

                if ($nome) {
                    $items += [PSCustomObject]@{
                        Nome = $nome
                        Tipo = if ($ehPasta) { "PASTA" } else { "ARQUIVO" }
                    }
                }
            }

        return $items
    }
    catch {
        Mostrar-Erro "Erro ao acessar: $Path"
        Mostrar-Detalhe $_.Exception.Message
        return @()
    }
}

function Criar-PastaWebDav {
    param(
        [string]$Url,
        [hashtable]$Headers,
        [System.Management.Automation.PSCredential]$Credencial
    )

    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method = "MKCOL"

        if ($Headers -and $Headers.Authorization) {
            $req.Headers.Add("Authorization", $Headers.Authorization)
        }

        if ($Credencial) {
            $req.Credentials = $Credencial
        }

        $req.GetResponse().Close()
        return $true
    }
    catch {
        return $false
    }
}

function Download-NexusArquivo {
    param(
        [string]$Url,
        [string]$Destino,
        [string]$Nome,
        [hashtable]$Headers,
        [int]$MaxTentativas = 3
    )

    for ($tentativa = 1; $tentativa -le $MaxTentativas; $tentativa++) {
        try {
            $sufixo = if ($MaxTentativas -gt 1 -and $tentativa -gt 1) { " (tentativa $tentativa)" } else { "" }
            Write-Host "Baixando: $Nome$sufixo" -NoNewline

            Invoke-WebRequest `
                -Uri $Url `
                -OutFile $Destino `
                -Headers $Headers `
                -UseBasicParsing `
                -ErrorAction Stop

            Write-Host "  OK" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "  ERRO" -ForegroundColor Red

            if ($tentativa -lt $MaxTentativas) {
                Mostrar-Detalhe "Aguardando para nova tentativa..."
                Start-Sleep -Seconds (2 * $tentativa)
            }
            else {
                Mostrar-Detalhe $_.Exception.Message
            }
        }
    }

    return $false
}

function Formatar-BytesAlinhadoNexus {
    param(
        [int64]$Bytes,
        [int64]$Total
    )

    $largura = ([string]$Total).Length
    return ([string]$Bytes).PadLeft($largura, " ")
}

function Mostrar-ProgressoBytesNexus {
    param(
        [int64]$Enviado,
        [int64]$Total
    )

    if ($Total -lt 0) {
        $Total = 0
    }

    if ($Enviado -lt 0) {
        $Enviado = 0
    }

    if ($Enviado -gt $Total) {
        $Enviado = $Total
    }

    $falta = $Total - $Enviado
    $percentual = if ($Total -gt 0) { ($Enviado / $Total) * 100 } else { 0 }

    Write-Host ""
    Write-Host ("  Enviado : {0} bytes" -f (Formatar-BytesAlinhadoNexus -Bytes $Enviado -Total $Total)) -ForegroundColor Cyan
    Write-Host ("  Total   : {0} bytes" -f (Formatar-BytesAlinhadoNexus -Bytes $Total -Total $Total)) -ForegroundColor DarkCyan
    Write-Host ("  Falta   : {0} bytes  ({1:N2}%)" -f (Formatar-BytesAlinhadoNexus -Bytes $falta -Total $Total), $percentual) -ForegroundColor Yellow
}

function Write-LinhaPainelUploadNexus {
    param(
        [string]$Texto,
        [string]$Cor = "Gray"
    )

    try {
        $larguraConsole = [Math]::Max(1, [Console]::BufferWidth - 1)
        if ($Texto.Length -lt $larguraConsole) {
            $Texto = $Texto.PadRight($larguraConsole, " ")
        }
    }
    catch {}

    Write-Host $Texto -ForegroundColor $Cor
}

function Mostrar-PainelUploadNexus {
    param(
        [string]$Nome,
        [int]$ChunkAtual,
        [int]$TotalChunks,
        [int64]$Enviado,
        [int64]$Total,
        [switch]$Finalizar
    )

    if ($Total -lt 0) {
        $Total = 0
    }

    if ($Enviado -lt 0) {
        $Enviado = 0
    }

    if ($Enviado -gt $Total) {
        $Enviado = $Total
    }

    $falta = $Total - $Enviado
    $percentual = if ($Total -gt 0) { ($Enviado / $Total) * 100 } else { 0 }
    $parte = if ($TotalChunks -gt 0) { "{0} / {1}" -f $ChunkAtual, $TotalChunks } else { "-" }

    try {
        if (-not $script:NexusUploadPainelAtivo) {
            Write-Host ""
            $script:NexusUploadPainelTop = [Console]::CursorTop
            $script:NexusUploadPainelAtivo = $true
        }
        else {
            [Console]::SetCursorPosition(0, $script:NexusUploadPainelTop)
        }
    }
    catch {
        Write-Host ""
    }

    Write-LinhaPainelUploadNexus -Texto ("Arquivo : {0}" -f $Nome) -Cor "Cyan"
    Write-LinhaPainelUploadNexus -Texto ("Parte   : {0}" -f $parte) -Cor "Gray"
    Write-LinhaPainelUploadNexus -Texto ("Enviado : {0} bytes" -f (Formatar-BytesAlinhadoNexus -Bytes $Enviado -Total $Total)) -Cor "Cyan"
    Write-LinhaPainelUploadNexus -Texto ("Total   : {0} bytes" -f (Formatar-BytesAlinhadoNexus -Bytes $Total -Total $Total)) -Cor "DarkCyan"
    Write-LinhaPainelUploadNexus -Texto ("Falta   : {0} bytes" -f (Formatar-BytesAlinhadoNexus -Bytes $falta -Total $Total)) -Cor "Yellow"
    Write-LinhaPainelUploadNexus -Texto ("Progresso: {0:N2}%" -f $percentual) -Cor "Yellow"

    if ($Finalizar) {
        $script:NexusUploadPainelAtivo = $false
        Write-Host ""
    }
}

function Invoke-NexusWebDavRequest {
    param(
        [string]$Url,
        [string]$Metodo,
        [hashtable]$Headers,
        [hashtable]$HeadersExtra,
        [int]$TimeoutMs = 1800000
    )

    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = $Metodo
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = $TimeoutMs

    if ($Headers -and $Headers.Authorization) {
        $req.Headers.Add("Authorization", $Headers.Authorization)
    }

    if ($HeadersExtra) {
        foreach ($key in $HeadersExtra.Keys) {
            $req.Headers.Add($key, [string]$HeadersExtra[$key])
        }
    }

    $resp = $req.GetResponse()
    $resp.Close()
}

function Invoke-NexusWebDavPutRange {
    param(
        [string]$Url,
        [string]$Arquivo,
        [int64]$Offset,
        [int64]$Quantidade,
        [hashtable]$Headers,
        [hashtable]$HeadersExtra,
        [int]$BufferSize = 1048576,
        [int]$TimeoutMs = 1800000
    )

    $entrada = $null
    $saida = $null
    $resp = $null

    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method = "PUT"
        $req.ContentType = "application/octet-stream"
        $req.ContentLength = $Quantidade
        $req.AllowWriteStreamBuffering = $false
        $req.SendChunked = $false
        $req.Timeout = $TimeoutMs
        $req.ReadWriteTimeout = $TimeoutMs

        if ($Headers -and $Headers.Authorization) {
            $req.Headers.Add("Authorization", $Headers.Authorization)
        }

        if ($HeadersExtra) {
            foreach ($key in $HeadersExtra.Keys) {
                $req.Headers.Add($key, [string]$HeadersExtra[$key])
            }
        }

        $entrada = [System.IO.File]::OpenRead($Arquivo)
        $entrada.Seek($Offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $saida = $req.GetRequestStream()

        $buffer = New-Object byte[] $BufferSize
        $restante = $Quantidade

        while ($restante -gt 0) {
            $ler = [Math]::Min([int64]$buffer.Length, $restante)
            $lidos = $entrada.Read($buffer, 0, [int]$ler)

            if ($lidos -le 0) {
                throw "Leitura interrompida antes do fim do chunk."
            }

            $saida.Write($buffer, 0, $lidos)
            $restante -= $lidos
        }

        $saida.Close()
        $saida = $null

        $resp = $req.GetResponse()
        $resp.Close()
        $resp = $null
    }
    finally {
        if ($saida) { $saida.Close() }
        if ($entrada) { $entrada.Close() }
        if ($resp) { $resp.Close() }
    }
}

function Upload-NexusArquivoChunked {
    param(
        [string]$Url,
        [string]$Arquivo,
        [string]$Nome,
        [hashtable]$Headers,
        [int]$MaxTentativas = 3,
        [int]$BufferSize = 1048576,
        [int]$TimeoutMs = 1800000,
        [int64]$TamanhoChunk = 10485760
    )

    $info = Get-Item -LiteralPath $Arquivo -ErrorAction Stop

    if ($Url -notmatch '^(?<DavRoot>.+/remote\.php/dav/)files/(?<User>[^/]+)/(?<Path>.+)$') {
        return $false
    }

    $davRoot = $matches.DavRoot
    $user = $matches.User
    $uploadId = "nexus-{0}" -f ([guid]::NewGuid().ToString())
    $uploadUrl = "${davRoot}uploads/$user/$uploadId"
    $headersDestino = @{
        Destination = $Url
        "OC-Total-Length" = $info.Length
    }

    $timerUpload = [System.Diagnostics.Stopwatch]::StartNew()
    $criouPasta = $false

    try {
        Invoke-NexusWebDavRequest `
            -Url $uploadUrl `
            -Metodo "MKCOL" `
            -Headers $Headers `
            -HeadersExtra $headersDestino `
            -TimeoutMs $TimeoutMs

        $criouPasta = $true

        $totalChunks = [int][Math]::Ceiling($info.Length / [double]$TamanhoChunk)

        if ($totalChunks -gt 10000) {
            throw "Arquivo grande demais para o tamanho de chunk atual."
        }

        $script:NexusUploadPainelAtivo = $false
        Mostrar-PainelUploadNexus `
            -Nome $Nome `
            -ChunkAtual 0 `
            -TotalChunks $totalChunks `
            -Enviado 0 `
            -Total $info.Length

        for ($chunk = 1; $chunk -le $totalChunks; $chunk++) {
            $offset = [int64](($chunk - 1) * $TamanhoChunk)
            $quantidade = [Math]::Min($TamanhoChunk, $info.Length - $offset)
            $chunkNome = "{0:D5}" -f $chunk
            $chunkUrl = "$uploadUrl/$chunkNome"

            for ($tentativa = 1; $tentativa -le $MaxTentativas; $tentativa++) {
                try {
                    Invoke-NexusWebDavPutRange `
                        -Url $chunkUrl `
                        -Arquivo $info.FullName `
                        -Offset $offset `
                        -Quantidade $quantidade `
                        -Headers $Headers `
                        -HeadersExtra $headersDestino `
                        -BufferSize $BufferSize `
                        -TimeoutMs $TimeoutMs

                    $enviado = [Math]::Min([int64]($offset + $quantidade), $info.Length)
                    Mostrar-PainelUploadNexus `
                        -Nome $Nome `
                        -ChunkAtual $chunk `
                        -TotalChunks $totalChunks `
                        -Enviado $enviado `
                        -Total $info.Length
                    break
                }
                catch {
                    if ($tentativa -ge $MaxTentativas) {
                        throw
                    }

                    Start-Sleep -Seconds (2 * $tentativa)
                }
            }
        }

        Invoke-NexusWebDavRequest `
            -Url "$uploadUrl/.file" `
            -Metodo "MOVE" `
            -Headers $Headers `
            -HeadersExtra $headersDestino `
            -TimeoutMs $TimeoutMs

        Mostrar-PainelUploadNexus `
            -Nome $Nome `
            -ChunkAtual $totalChunks `
            -TotalChunks $totalChunks `
            -Enviado $info.Length `
            -Total $info.Length `
            -Finalizar

        $timerUpload.Stop()
        $mb = if ($info.Length -gt 0) { $info.Length / 1MB } else { 0 }
        $velocidade = if ($timerUpload.Elapsed.TotalSeconds -gt 0) {
            " ({0:N2} MB/s)" -f ($mb / $timerUpload.Elapsed.TotalSeconds)
        }
        else {
            ""
        }

        Write-Host "  OK$velocidade" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ERRO" -ForegroundColor Red
        Mostrar-Detalhe $_.Exception.Message
        return $false
    }
    finally {
        if ($criouPasta) {
            try {
                Invoke-NexusWebDavRequest `
                    -Url $uploadUrl `
                    -Metodo "DELETE" `
                    -Headers $Headers `
                    -HeadersExtra $null `
                    -TimeoutMs $TimeoutMs
            }
            catch {}
        }
    }
}

function Upload-NexusArquivo {
    param(
        [string]$Url,
        [string]$Arquivo,
        [string]$Nome,
        [hashtable]$Headers,
        [int]$MaxTentativas = 3,
        [int]$BufferSize = 1048576,
        [int]$TimeoutMs = 1800000,
        [int64]$TamanhoChunk = 10485760,
        [int64]$LimiteChunkedBytes = 52428800
    )

    $infoInicial = Get-Item -LiteralPath $Arquivo -ErrorAction Stop

    if ($infoInicial.Length -ge $LimiteChunkedBytes) {
        Write-Host "Enviando: $Nome" -NoNewline
        return Upload-NexusArquivoChunked `
            -Url $Url `
            -Arquivo $Arquivo `
            -Nome $Nome `
            -Headers $Headers `
            -MaxTentativas $MaxTentativas `
            -BufferSize $BufferSize `
            -TimeoutMs $TimeoutMs `
            -TamanhoChunk $TamanhoChunk
    }

    for ($tentativa = 1; $tentativa -le $MaxTentativas; $tentativa++) {
        $entrada = $null
        $saida = $null
        $resp = $null

        try {
            $sufixo = if ($MaxTentativas -gt 1 -and $tentativa -gt 1) { " (tentativa $tentativa)" } else { "" }
            Write-Host "Enviando: $Nome$sufixo" -NoNewline

            $info = Get-Item -LiteralPath $Arquivo -ErrorAction Stop
            $timerUpload = [System.Diagnostics.Stopwatch]::StartNew()

            [System.Net.ServicePointManager]::Expect100Continue = $false

            $req = [System.Net.HttpWebRequest]::Create($Url)
            $req.Method = "PUT"
            $req.ContentType = "application/octet-stream"
            $req.ContentLength = $info.Length
            $req.AllowWriteStreamBuffering = $false
            $req.SendChunked = $false
            $req.Timeout = $TimeoutMs
            $req.ReadWriteTimeout = $TimeoutMs

            if ($Headers -and $Headers.Authorization) {
                $req.Headers.Add("Authorization", $Headers.Authorization)
            }

            $buffer = New-Object byte[] $BufferSize
            $entrada = [System.IO.File]::OpenRead($info.FullName)
            $saida = $req.GetRequestStream()

            while (($lidos = $entrada.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $saida.Write($buffer, 0, $lidos)
            }

            $saida.Close()
            $saida = $null

            $resp = $req.GetResponse()
            $resp.Close()
            $resp = $null

            $timerUpload.Stop()
            $mb = if ($info.Length -gt 0) { $info.Length / 1MB } else { 0 }
            $velocidade = if ($timerUpload.Elapsed.TotalSeconds -gt 0) {
                " ({0:N2} MB/s)" -f ($mb / $timerUpload.Elapsed.TotalSeconds)
            }
            else {
                ""
            }

            Write-Host "  OK$velocidade" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "  ERRO" -ForegroundColor Red

            if ($tentativa -lt $MaxTentativas) {
                Mostrar-Detalhe "Aguardando para nova tentativa..."
                Start-Sleep -Seconds (2 * $tentativa)
            }
            else {
                Mostrar-Detalhe $_.Exception.Message
            }
        }
        finally {
            if ($saida) {
                $saida.Close()
            }

            if ($entrada) {
                $entrada.Close()
            }

            if ($resp) {
                $resp.Close()
            }
        }
    }

    return $false
}

# ============================================
# FUNCOES - VERSOES
# ============================================

function Get-NexusSeries {
    param(
        [string]$Cloud,
        [string]$Base = "/VERSOES",
        [System.Management.Automation.PSCredential]$Credencial
    )

    @(Get-NexusCloudItemsComTipo -Cloud $Cloud -Path $Base -Credencial $Credencial) |
        Where-Object {
            $_.Tipo -eq "PASTA" -and $_.Nome -match '^v\d+'
        } |
        Sort-Object {
            [int]($_.Nome -replace '^v', '')
        }
}

function Get-NexusVersoes {
    param(
        [string]$Cloud,
        [string]$Path,
        [System.Management.Automation.PSCredential]$Credencial
    )

    @(Get-NexusCloudItemsComTipo -Cloud $Cloud -Path $Path -Credencial $Credencial) |
        Where-Object {
            $_.Tipo -eq "PASTA" -and $_.Nome -match '^\d+\.'
        } |
        Sort-Object {
            try { [version]$_.Nome } catch { [version]"0.0.0.0" }
        }
}

function Test-NexusArquivoVersaoValido {
    param(
        [string]$Nome
    )

    if ([string]::IsNullOrWhiteSpace($Nome)) {
        return $false
    }

    if ($Nome -notmatch '\.(rar|zip)$') {
        return $false
    }

    $n = $Nome.ToLower()

    if ($n -match 'update|manager_update') {
        return $false
    }

    if ($n -match 'boleto|cte|mdfe|nfce|nfe|nfse|nfse2|nfcom') {
        return $false
    }

    if ($n -match 'api|pdv|farmacia|food|vet|posto|producao|spedmanute|receituario|vendas|android') {
        return $false
    }

    if ($n -match 'max_manager') {
        return $true
    }

    if ($n -match 'max_manute') {
        return $true
    }

    return $false
}

function Get-NexusArquivosVersaoValidos {
    param(
        [array]$Arquivos
    )

    return @($Arquivos | Where-Object {
        Test-NexusArquivoVersaoValido -Nome $_
    })
}

function Interpretar-SelecaoNumericaNexus {
    param(
        [string]$Texto,
        [array]$Itens
    )

    $selecionados = @()

    if ([string]::IsNullOrWhiteSpace($Texto)) {
        return @()
    }

    $partes = $Texto -split ","

    foreach ($parte in $partes) {
        $parte = $parte.Trim()

        if ($parte -match '^\d+$') {
            $idx = [int]$parte - 1

            if ($idx -ge 0 -and $idx -lt $Itens.Count) {
                $selecionados += $Itens[$idx]
            }
        }
    }

    return $selecionados
}

# ============================================
# FUNCOES - DOWNLOAD DE VERSAO (UNIFICADO)
# ============================================

function Invoke-NexusDownloadVersao {
    # Funcao unificada usada pelo modulo_atualizar_sistema e modulo_instalador.
    # Lista os arquivos validos de uma versao no WebDAV e os baixa para o destino.
    param(
        [string]$Cloud,
        [string]$Base,
        [string]$Serie,
        [string]$Versao,
        [string]$Destino,
        [System.Management.Automation.PSCredential]$Credencial,
        [hashtable]$Headers
    )

    $pathVersao = "$Base/$Serie/$Versao"
    $arquivos   = @(Get-NexusCloudItems -Cloud $Cloud -Path $pathVersao -Credencial $Credencial)
    $validos    = @(Get-NexusArquivosVersaoValidos -Arquivos $arquivos)

    if ($validos.Count -eq 0) {
        Mostrar-Aviso "Nenhum arquivo valido encontrado em $Versao."
        return [PSCustomObject]@{ OK = 0; ERRO = 0 }
    }

    Write-Host ""
    Write-Host "Arquivos da versao $Versao que serao baixados:" -ForegroundColor Cyan

    foreach ($f in $validos) {
        Write-Host " - $f"
    }

    Write-Host ""

    $ok   = 0
    $erro = 0

    foreach ($f in $validos) {
        $url   = "$Cloud$pathVersao/$f"
        $saida = Join-Path $Destino $f

        if (Download-NexusArquivo -Url $url -Destino $saida -Nome $f -Headers $Headers) {
            $ok++
        }
        else {
            $erro++
        }
    }

    return [PSCustomObject]@{ OK = $ok; ERRO = $erro }
}
