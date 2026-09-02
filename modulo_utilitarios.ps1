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
    Write-Host "╔══════════ UTILITARIOS ══════════╗" -ForegroundColor Cyan
    Write-Host "║             NEXUS               ║" -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  SUPORTE" -ForegroundColor Yellow
    Write-Host "  [1] Corrigir WMI" -ForegroundColor Gray
    Write-Host "  [2] Instalar/Verificar ODBC" -ForegroundColor Gray
    Write-Host "  [3] Registrar Servidor no Cloud" -ForegroundColor Gray
    Write-Host "  [4] Abrir Pasta do Sistema" -ForegroundColor Gray
    Write-Host ""

    Write-Host "  [0] Voltar" -ForegroundColor DarkGray
    Write-Host ""
}

while ($true) {
    Clear-Host
    Mostrar-MenuUtilitariosNexus

    $op = (Read-Host "Escolha").Trim()

    switch ($op) {
        "1" { Corrigir-WmiNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "2" { Instalar-VerificarOdbcNexus }
        "3" { Registrar-ServidorCloudNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "4" { Abrir-PastaSistemaNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "0" { return }
        default { continue }
    }
}
