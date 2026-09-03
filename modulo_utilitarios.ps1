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
$script:WebDavUser = $script:Cred.UserName
$script:CloudDavRoot = "https://cloud.maxdata.com.br/remote.php/dav/files/$script:WebDavUser"

function Baixar-ArquivoPublicoUtilitario {
    param(
        [string]$Caminho,
        [string]$Destino,
        [string]$Nome
    )

    $url = Get-UrlSemCacheUtilitario "$script:NexusRawBase/$Caminho"
    $downloadHeaders = @{
        "Cache-Control" = "no-cache"
        "Pragma" = "no-cache"
    }

    try {
        Invoke-WebRequest `
            -Uri $url `
            -OutFile $Destino `
            -Headers $downloadHeaders `
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

function Pausar-UtilitarioNexus {
    param([string]$Nome = "processo")

    Mostrar-TempoDesdeConfirmacaoNexus -Nome $Nome
    Read-Host "`nENTER para voltar" | Out-Null
}

function Get-UrlSemCacheUtilitario {
    param([string]$Url)

    $sep = if ($Url.Contains("?")) { "&" } else { "?" }
    return "$Url${sep}cb=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
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

function Test-ArquivoExecutavelNexus {
    param([string]$Caminho)

    if (-not (Test-Path -LiteralPath $Caminho)) {
        return $false
    }

    try {
        $stream = [System.IO.File]::OpenRead($Caminho)
        try {
            if ($stream.Length -lt 2) {
                return $false
            }

            $primeiro = $stream.ReadByte()
            $segundo = $stream.ReadByte()
            return ($primeiro -eq 0x4D -and $segundo -eq 0x5A)
        }
        finally {
            $stream.Close()
        }
    }
    catch {
        return $false
    }
}

function Test-ArquivoRarNexus {
    param([string]$Caminho)

    if (-not (Test-Path -LiteralPath $Caminho)) {
        return $false
    }

    try {
        $stream = [System.IO.File]::OpenRead($Caminho)
        try {
            if ($stream.Length -lt 7) {
                return $false
            }

            $assinatura = New-Object byte[] 7
            $lidos = $stream.Read($assinatura, 0, $assinatura.Length)

            return (
                $lidos -eq 7 -and
                $assinatura[0] -eq 0x52 -and
                $assinatura[1] -eq 0x61 -and
                $assinatura[2] -eq 0x72 -and
                $assinatura[3] -eq 0x21 -and
                $assinatura[4] -eq 0x1A -and
                $assinatura[5] -eq 0x07
            )
        }
        finally {
            $stream.Close()
        }
    }
    catch {
        return $false
    }
}

function Get-HtmlInputValueNexus {
    param(
        [string]$Html,
        [string]$Name
    )

    $pattern = '<input\b(?=[^>]*\bname="' + [regex]::Escape($Name) + '")[^>]*\bvalue="([^"]*)"'
    $match = [regex]::Match($Html, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($match.Success) {
        return [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    }

    return $null
}

function Get-GoogleDriveDownloadUrlNexus {
    param([string]$FileId)

    $urlAviso = "https://drive.google.com/uc?export=download&id=$FileId"
    $resposta = Invoke-WebRequest -Uri $urlAviso -UseBasicParsing -ErrorAction Stop

    if ($resposta.Headers["Content-Disposition"]) {
        return $urlAviso
    }

    $html = [string]$resposta.Content
    $actionMatch = [regex]::Match($html, '<form\b(?=[^>]*\bid="download-form")[^>]*\baction="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $action = if ($actionMatch.Success) {
        [System.Net.WebUtility]::HtmlDecode($actionMatch.Groups[1].Value)
    }
    else {
        "https://drive.usercontent.google.com/download"
    }

    if ($action -match '^/') {
        $action = "https://drive.usercontent.google.com$action"
    }
    elseif ($action -notmatch '^https?://') {
        $action = "https://drive.usercontent.google.com/download"
    }

    $id = Get-HtmlInputValueNexus -Html $html -Name "id"
    $export = Get-HtmlInputValueNexus -Html $html -Name "export"
    $confirm = Get-HtmlInputValueNexus -Html $html -Name "confirm"
    $uuid = Get-HtmlInputValueNexus -Html $html -Name "uuid"

    if ([string]::IsNullOrWhiteSpace($id)) {
        $id = $FileId
    }

    if ([string]::IsNullOrWhiteSpace($export)) {
        $export = "download"
    }

    $partes = @(
        "id=$([uri]::EscapeDataString($id))",
        "export=$([uri]::EscapeDataString($export))"
    )

    if (-not [string]::IsNullOrWhiteSpace($confirm)) {
        $partes += "confirm=$([uri]::EscapeDataString($confirm))"
    }

    if (-not [string]::IsNullOrWhiteSpace($uuid)) {
        $partes += "uuid=$([uri]::EscapeDataString($uuid))"
    }

    return "${action}?$($partes -join '&')"
}

function Obter-7ZipNexus {
    param([string]$TempPath)

    $candidatos = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($candidato in $candidatos) {
        if (Test-Path -LiteralPath $candidato) {
            return $candidato
        }
    }

    Write-Host "7-Zip nao encontrado. Instalando..." -ForegroundColor Cyan

    $instalador = Join-Path $TempPath "7zip_installer.exe"
    $ok = Download-NexusArquivo -Url "https://www.7-zip.org/a/7z2409-x64.exe" -Destino $instalador -Nome "7-Zip" -Headers $null

    if (-not $ok) {
        return $null
    }

    Start-Process -FilePath $instalador -ArgumentList "/S" -Wait

    foreach ($candidato in $candidatos) {
        if (Test-Path -LiteralPath $candidato) {
            return $candidato
        }
    }

    return $null
}

function Abrir-MaxHubNexus {
    Mostrar-TituloNexus "ABRIR MAXHUB"

    $fileId = "18xlV8SG8K1XeaW6yikuGTG38W3sViO9N"
    $raizTemp = Join-Path $env:TEMP "NEXUS_MAXHUB"
    $pastaTemp = Join-Path $raizTemp ([guid]::NewGuid().ToString())
    $pastaExtracao = Join-Path $pastaTemp "app"
    $rar = Join-Path $pastaTemp "MaxHub.rar"

    try {
        New-Item -ItemType Directory -Path $pastaTemp -Force | Out-Null
        New-Item -ItemType Directory -Path $pastaExtracao -Force | Out-Null

        Write-Host "Baixando MaxHub..." -ForegroundColor Cyan
        $url = Get-GoogleDriveDownloadUrlNexus -FileId $fileId
        $ok = Download-NexusArquivo -Url $url -Destino $rar -Nome "MaxHub.rar" -Headers $null

        if (-not $ok) {
            throw "Nao foi possivel baixar o MaxHub."
        }

        if (-not (Test-ArquivoRarNexus -Caminho $rar)) {
            throw "O Google Drive nao entregou um pacote RAR valido. Verifique se o link esta publico."
        }

        $sevenZip = Obter-7ZipNexus -TempPath $pastaTemp
        if (-not $sevenZip) {
            throw "7-Zip indisponivel para extrair o MaxHub."
        }

        Write-Host ""
        Write-Host "Extraindo MaxHub..." -ForegroundColor Cyan
        & $sevenZip x $rar "-o$pastaExtracao" -y | Out-Null

        $exe = Get-ChildItem -LiteralPath $pastaExtracao -Filter "*.exe" -Recurse |
            Where-Object { $_.Name -like "MaxHub*.exe" } |
            Select-Object -First 1

        if (-not $exe) {
            $exe = Get-ChildItem -LiteralPath $pastaExtracao -Filter "*.exe" -Recurse |
                Select-Object -First 1
        }

        if (-not $exe) {
            throw "Nenhum executavel foi encontrado dentro do pacote MaxHub."
        }

        if (-not (Test-ArquivoExecutavelNexus -Caminho $exe.FullName)) {
            throw "O arquivo extraido nao parece ser um executavel valido."
        }

        Write-Host ""
        Write-Host "Abrindo MaxHub..." -ForegroundColor Cyan
        Write-Host "O NEXUS vai aguardar o MaxHub fechar para limpar o arquivo temporario." -ForegroundColor DarkGray

        Start-Process -FilePath $exe.FullName -PassThru -Wait | Out-Null

        Mostrar-Sucesso "MaxHub fechado."
    }
    catch {
        Mostrar-Erro "Falha ao abrir MaxHub."
        Mostrar-Detalhe $_.Exception.Message
    }
    finally {
        try {
            if (Test-Path -LiteralPath $pastaTemp) {
                Remove-Item -LiteralPath $pastaTemp -Recurse -Force -ErrorAction Stop
            }
        }
        catch {
            Mostrar-Aviso "Nao foi possivel remover todos os arquivos temporarios do MaxHub."
            Mostrar-Detalhe $_.Exception.Message
        }
    }
}

function Get-BancoMaxIniNexus {
    param([string]$MaxPath)

    $ini = Join-Path $MaxPath "max.ini"
    if (-not (Test-Path -LiteralPath $ini)) {
        return "Desconhecido"
    }

    $linha = Get-Content -LiteralPath $ini -ErrorAction SilentlyContinue |
        Where-Object { $_ -match 'Initial Catalog\s*=' } |
        Select-Object -First 1

    if (-not $linha) {
        return "Desconhecido"
    }

    return (($linha -split '=', 2)[1]).Trim()
}

function Get-IpLocalNexus {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notlike "169.254.*" -and
                $_.IPAddress -ne "127.0.0.1" -and
                $_.PrefixOrigin -ne "WellKnown"
            } |
            Select-Object -First 1 -ExpandProperty IPAddress

        if ($ip) {
            return $ip
        }
    }
    catch {}

    try {
        $ip = (ipconfig | Select-String -Pattern "IPv4" | Select-Object -First 1).ToString()
        if ($ip -match ':\s*(.+)$') {
            return $matches[1].Trim()
        }
    }
    catch {}

    return "Indefinido"
}

function Get-EmpresaManagerNexus {
    param([string]$Banco)

    if ([string]::IsNullOrWhiteSpace($Banco) -or $Banco -eq "Desconhecido") {
        return "Nao Identificada"
    }

    try {
        $empresa = & sqlcmd -S localhost -d $Banco -E -Q "SET NOCOUNT ON; SELECT TOP 1 cofEmpRazao FROM config" -h -1 2>$null |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -First 1

        if ($empresa) {
            return $empresa.Trim()
        }
    }
    catch {}

    return "Nao Identificada"
}

function Get-VersaoManagerNexus {
    param([string]$MaxPath)

    $exe = Join-Path $MaxPath "MAX_Manager2.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        return "Indefinida"
    }

    try {
        $versao = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
        if (-not [string]::IsNullOrWhiteSpace($versao)) {
            return $versao
        }
    }
    catch {}

    return "Indefinida"
}

function Get-InfoServidorNexus {
    $maxPath = Get-PastaMaxPadrao
    if ([string]::IsNullOrWhiteSpace($maxPath) -or -not (Test-Path -LiteralPath $maxPath)) {
        $maxPath = "C:\MAX"
    }

    $banco = Get-BancoMaxIniNexus -MaxPath $maxPath

    return [PSCustomObject]@{
        Origem = "NEXUS"
        DataHora = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Computador = $env:COMPUTERNAME
        UsuarioWindows = [Environment]::UserName
        IpLocal = Get-IpLocalNexus
        PastaMax = $maxPath
        Banco = $banco
        Empresa = Get-EmpresaManagerNexus -Banco $banco
        VersaoManager = Get-VersaoManagerNexus -MaxPath $maxPath
        Windows = (Get-CimInstance Win32_OperatingSystem).Caption
        PowerShell = $PSVersionTable.PSVersion.ToString()
    }
}

function Registrar-ServidorCloudNexus {
    Mostrar-TituloNexus "REGISTRAR SERVIDOR NO CLOUD"

    Write-Host "Coletando informacoes do servidor..." -ForegroundColor Cyan
    $info = Get-InfoServidorNexus

    Write-Host ""
    Write-Host "Computador: $($info.Computador)" -ForegroundColor Cyan
    Write-Host "IP Local: $($info.IpLocal)" -ForegroundColor Cyan
    Write-Host "Banco: $($info.Banco)" -ForegroundColor Cyan
    Write-Host "Empresa: $($info.Empresa)" -ForegroundColor Cyan
    Write-Host "Versao Manager: $($info.VersaoManager)" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirmar-Acao "Registrar estas informacoes no Cloud")) {
        Mostrar-Aviso "Operacao cancelada."
        return
    }

    $pastaCloud = "$script:CloudDavRoot/REGISTRO_SERVIDORES"
    Criar-PastaWebDav -Url $pastaCloud -Headers $script:Headers | Out-Null

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $nomeBase = ($info.Computador -replace '[^a-zA-Z0-9_.-]', '_')
    $json = Join-Path $env:TEMP "NEXUS_REGISTRO_SERVIDOR_$nomeBase`_$timestamp.json"
    $txt = Join-Path $env:TEMP "NEXUS_REGISTRO_SERVIDOR_$nomeBase`_$timestamp.txt"

    $info | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $json -Encoding UTF8

    @(
        "========= REGISTRO SERVIDOR NEXUS =========",
        "",
        "Data/Hora: $($info.DataHora)",
        "Computador: $($info.Computador)",
        "Usuario Windows: $($info.UsuarioWindows)",
        "IP Local: $($info.IpLocal)",
        "Pasta MAX: $($info.PastaMax)",
        "Banco: $($info.Banco)",
        "Empresa: $($info.Empresa)",
        "Versao Manager: $($info.VersaoManager)",
        "Windows: $($info.Windows)",
        "PowerShell: $($info.PowerShell)"
    ) | Set-Content -LiteralPath $txt -Encoding UTF8

    try {
        $jsonNome = [System.Uri]::EscapeDataString((Split-Path $json -Leaf))
        $txtNome = [System.Uri]::EscapeDataString((Split-Path $txt -Leaf))

        $okJson = Upload-NexusArquivo -Url "$pastaCloud/$jsonNome" -Arquivo $json -Nome (Split-Path $json -Leaf) -Headers $script:Headers
        $okTxt = Upload-NexusArquivo -Url "$pastaCloud/$txtNome" -Arquivo $txt -Nome (Split-Path $txt -Leaf) -Headers $script:Headers

        if ($okJson -and $okTxt) {
            Mostrar-Sucesso "Registro enviado para o Cloud."
            Write-Host "Pasta: /REGISTRO_SERVIDORES" -ForegroundColor Cyan
        }
        else {
            Mostrar-Erro "Falha ao enviar um ou mais arquivos de registro."
        }
    }
    finally {
        Remove-Item -LiteralPath $json -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $txt -Force -ErrorAction SilentlyContinue
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

function Mostrar-MenuUtilitariosNexus {
    Write-Host "NEXUS  |  UTILITARIOS" -ForegroundColor Cyan
    Write-Host "Automacao tecnica" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "SUPORTE" -ForegroundColor Yellow
    Write-Host "  [1] Corrigir WMI" -ForegroundColor Gray
    Write-Host "  [2] Instalar/Verificar ODBC" -ForegroundColor Gray
    Write-Host "  [3] Abrir MaxHub" -ForegroundColor Gray
    Write-Host "  [4] Abrir Pasta do Sistema" -ForegroundColor Gray
    Write-Host ""

    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [0] Voltar" -ForegroundColor DarkGray
    Write-Host ""
}

while ($true) {
    Clear-Host
    Mostrar-MenuUtilitariosNexus

    $op = (Read-Host "Escolha").Trim()

    switch ($op) {
        "1" { Corrigir-WmiNexus; Pausar-UtilitarioNexus -Nome "correcao WMI" }
        "2" { Instalar-VerificarOdbcNexus }
        "3" { Abrir-MaxHubNexus; Pausar-UtilitarioNexus -Nome "MaxHub" }
        "4" { Abrir-PastaSistemaNexus; Pausar-UtilitarioNexus -Nome "abrir pasta" }
        "0" { return }
        default { continue }
    }
}
