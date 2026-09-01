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

function Test-AdminNexus {
    return (
        New-Object Security.Principal.WindowsPrincipal(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )
    ).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Test-ProgramaInstaladoUtilitario {
    param([string]$Nome)

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $paths) {
        $item = Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$Nome*" } |
            Select-Object -First 1

        if ($item) {
            return $true
        }
    }

    return $false
}

function Test-SqlNativeClientUtilitario {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $paths) {
        $item = Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'SQL Server.*Native Client' } |
            Select-Object -First 1

        if ($item) {
            return $true
        }
    }

    $driverPaths = @(
        "HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server Native Client 11.0",
        "HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBCINST.INI\SQL Server Native Client 11.0"
    )

    foreach ($driverPath in $driverPaths) {
        if (Test-Path $driverPath) {
            return $true
        }
    }

    return $false
}

function Test-CloudNexus {
    try {
        $req = [System.Net.HttpWebRequest]::Create($script:Cloud)
        $req.Method = "HEAD"
        $req.Headers.Add("Authorization", $script:Headers.Authorization)
        $req.Timeout = 10000
        $resp = $req.GetResponse()
        $resp.Close()
        return "OK"
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            if ($status -in @(401, 403, 404, 405)) {
                return "Servidor respondeu HTTP $status"
            }
        }

        return "Falha: $($_.Exception.Message)"
    }
    catch {
        return "Falha: $($_.Exception.Message)"
    }
}

function Get-DiagnosticoNexus {
    $sevenZip = Test-Path "C:\Program Files\7-Zip\7z.exe"
    $nativeClient = Test-SqlNativeClientUtilitario
    $odbc17 = Test-ProgramaInstaladoUtilitario "ODBC Driver 17 for SQL Server"
    $temp = [IO.Path]::GetFullPath($env:TEMP)

    return [PSCustomObject]@{
        DataHora = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        UsuarioWindows = [Environment]::UserName
        Computador = [Environment]::MachineName
        Windows = (Get-CimInstance Win32_OperatingSystem).Caption
        PowerShell = $PSVersionTable.PSVersion.ToString()
        Administrador = Test-AdminNexus
        SevenZip = $sevenZip
        SqlNativeClient = $nativeClient
        OdbcDriver17 = $odbc17
        Temp = $temp
        Cloud = Test-CloudNexus
    }
}

function Mostrar-DiagnosticoNexus {
    $diag = Get-DiagnosticoNexus

    Mostrar-TituloNexus "DIAGNOSTICO DO AMBIENTE"

    Write-Host "Data/Hora: $($diag.DataHora)" -ForegroundColor Cyan
    Write-Host "Usuario Windows: $($diag.UsuarioWindows)" -ForegroundColor Cyan
    Write-Host "Computador: $($diag.Computador)" -ForegroundColor Cyan
    Write-Host "Windows: $($diag.Windows)" -ForegroundColor Cyan
    Write-Host "PowerShell: $($diag.PowerShell)" -ForegroundColor Cyan
    Write-Host "Administrador: $($diag.Administrador)" -ForegroundColor Cyan
    Write-Host "7-Zip: $($diag.SevenZip)" -ForegroundColor Cyan
    Write-Host "SQL Server Native Client: $($diag.SqlNativeClient)" -ForegroundColor Cyan
    Write-Host "ODBC Driver 17 for SQL Server: $($diag.OdbcDriver17)" -ForegroundColor Cyan
    Write-Host "TEMP: $($diag.Temp)" -ForegroundColor Cyan
    Write-Host "Cloud: $($diag.Cloud)" -ForegroundColor Cyan
}

function Gerar-LogSuporteNexus {
    Mostrar-TituloNexus "GERAR LOG PARA SUPORTE"

    $diag = Get-DiagnosticoNexus
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path $desktop)) {
        $desktop = $env:TEMP
    }

    $saida = Join-Path $desktop ("NEXUS_Diagnostico_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

    $linhas = @(
        "========= NEXUS - LOG PARA SUPORTE =========",
        "",
        "Data/Hora: $($diag.DataHora)",
        "Usuario Windows: $($diag.UsuarioWindows)",
        "Computador: $($diag.Computador)",
        "Windows: $($diag.Windows)",
        "PowerShell: $($diag.PowerShell)",
        "Administrador: $($diag.Administrador)",
        "7-Zip: $($diag.SevenZip)",
        "SQL Server Native Client: $($diag.SqlNativeClient)",
        "ODBC Driver 17 for SQL Server: $($diag.OdbcDriver17)",
        "TEMP: $($diag.Temp)",
        "Cloud: $($diag.Cloud)",
        "",
        "Arquivos temporarios NEXUS:",
        "----------------------------------------"
    )

    $temp = [IO.Path]::GetFullPath($env:TEMP)
    $arquivos = @(Get-ChildItem -LiteralPath $temp -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "nexus_*" -or
            $_.Name -like "NEXUS_*.ps1" -or
            $_.Name -like "modulo_*.ps1" -or
            $_.Name -like "*.part*"
        } |
        Select-Object -First 200)

    if ($arquivos.Count -eq 0) {
        $linhas += "Nenhum arquivo temporario encontrado."
    }
    else {
        foreach ($arquivo in $arquivos) {
            $linhas += "$($arquivo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) | $($arquivo.Length) | $($arquivo.FullName)"
        }
    }

    Set-Content -LiteralPath $saida -Value $linhas -Encoding UTF8

    Mostrar-Sucesso "Log gerado."
    Write-Host "Arquivo: $saida" -ForegroundColor Cyan
    Abrir-PastaNexus (Split-Path $saida -Parent)
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

function Limpar-TemporariosNexus {
    Mostrar-TituloNexus "LIMPAR TEMPORARIOS DO NEXUS"

    if (-not (Confirmar-Acao "Limpar arquivos temporarios do NEXUS")) {
        return
    }

    $temp = [IO.Path]::GetFullPath($env:TEMP)
    $removidos = 0

    $itens = @(Get-ChildItem -LiteralPath $temp -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and (
                $_.Name -like "nexus_*" -or
                $_.Name -like "NEXUS_*.ps1" -or
                $_.Name -like "modulo_*.ps1" -or
                $_.Name -like "*.part*"
            )
        })

    foreach ($item in $itens) {
        try {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            $removidos++
        }
        catch {
            Mostrar-Aviso "Nao foi possivel remover: $($item.FullName)"
        }
    }

    Mostrar-Sucesso "$removidos item(ns) removido(s)."
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
    Write-Host "4 - Limpar Temporarios do NEXUS"
    Write-Host "5 - Diagnostico do Ambiente"
    Write-Host "6 - Gerar Log para Suporte"
    Write-Host "7 - Explorar Arquivos Uteis"
    Write-Host "0 - Voltar"
    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    switch ($op) {
        "1" { Corrigir-WmiNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "2" { Instalar-VerificarOdbcNexus }
        "3" { Abrir-PastaSistemaNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "4" { Limpar-TemporariosNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "5" { Mostrar-DiagnosticoNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "6" { Gerar-LogSuporteNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "7" { Explorar-ArquivosUteisNexus }
        "0" { break }
        default { continue }
    }
}

Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
