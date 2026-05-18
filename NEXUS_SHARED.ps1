# ============================================
# NEXUS SHARED
# ============================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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

    if ($ChamadoPeloCore -ne 1) {
        Read-Host "`nPressione ENTER para continuar"
    }
}

function Confirmar-Acao {
    param(
        [string]$Mensagem = "Deseja continuar?"
    )

    $resp = (Read-Host "$Mensagem (S/N)").Trim().ToUpper()
    return ($resp -eq "S")
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

function Mostrar-TempoExecucao {
    param(
        [datetime]$Inicio,
        [string]$Nome = "processo"
    )

    $tempo = (Get-Date) - $Inicio
    Write-Host ""
    Write-Host "Tempo de execucao ($Nome): $($tempo.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
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

function Upload-NexusArquivo {
    param(
        [string]$Url,
        [string]$Arquivo,
        [string]$Nome,
        [hashtable]$Headers,
        [int]$MaxTentativas = 3
    )

    for ($tentativa = 1; $tentativa -le $MaxTentativas; $tentativa++) {
        try {
            $sufixo = if ($MaxTentativas -gt 1 -and $tentativa -gt 1) { " (tentativa $tentativa)" } else { "" }
            Write-Host "Enviando: $Nome$sufixo" -NoNewline

            Invoke-WebRequest `
                -Uri $Url `
                -Method Put `
                -InFile $Arquivo `
                -Headers $Headers `
                -UseBasicParsing `
                -ErrorAction Stop | Out-Null

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
        [string]$Nome,
        [switch]$Completo
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

    if ($Completo -and $n -match 'max_manute') {
        return $true
    }

    return $false
}

function Get-NexusArquivosVersaoValidos {
    param(
        [array]$Arquivos,
        [switch]$Completo
    )

    return @($Arquivos | Where-Object {
        Test-NexusArquivoVersaoValido -Nome $_ -Completo:$Completo
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
# FUNCOES - DOWNLOAD DE VERSAO
# ============================================

function Invoke-NexusDownloadVersao {
    param(
        [string]$Cloud,
        [string]$Base,
        [string]$Serie,
        [string]$Versao,
        [string]$Destino,
        [System.Management.Automation.PSCredential]$Credencial,
        [hashtable]$Headers,
        [switch]$Completo
    )

    $pathVersao = "$Base/$Serie/$Versao"
    $arquivos = @(Get-NexusCloudItems -Cloud $Cloud -Path $pathVersao -Credencial $Credencial)
    $validos = @(Get-NexusArquivosVersaoValidos -Arquivos $arquivos -Completo:$Completo)

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

    $ok = 0
    $erro = 0

    foreach ($f in $validos) {
        $url = "$Cloud$pathVersao/$f"
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