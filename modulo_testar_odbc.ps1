param(
    [string]$Usuario,
    [string]$SenhaPlain,
    [int]$ChamadoPeloCore = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Mostrar-TituloNexus {
    param([string]$Titulo)

    Clear-Host
    Write-Host "========= $Titulo =========" -ForegroundColor Cyan
    Write-Host ""
}

function Mostrar-Sucesso { param([string]$Mensagem) Write-Host $Mensagem -ForegroundColor Green }
function Mostrar-Erro { param([string]$Mensagem) Write-Host $Mensagem -ForegroundColor Red }
function Mostrar-Aviso { param([string]$Mensagem) Write-Host $Mensagem -ForegroundColor Yellow }
function Mostrar-Detalhe { param([string]$Mensagem) Write-Host $Mensagem -ForegroundColor DarkGray }

function Pausar-Nexus {
    param([int]$ChamadoPeloCore = 0)

    if ($ChamadoPeloCore -ne 1) {
        Read-Host "`nPressione ENTER para continuar"
    }
}

function Test-ProgramaInstalado {
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

function Baixar-ArquivoPublico {
    param(
        [string]$Url,
        [string]$Destino,
        [string]$Nome,
        [int]$MaxTentativas = 3
    )

    for ($tentativa = 1; $tentativa -le $MaxTentativas; $tentativa++) {
        try {
            $sufixo = if ($MaxTentativas -gt 1 -and $tentativa -gt 1) { " (tentativa $tentativa)" } else { "" }
            Write-Host "Baixando: $Nome$sufixo" -NoNewline

            Invoke-WebRequest `
                -Uri $Url `
                -OutFile $Destino `
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

function Instalar-MSI {
    param(
        [string]$Nome,
        [string]$Url,
        [string]$TempPath,
        [string]$ArgumentosExtras = "",
        [string[]]$NomesValidacao = @()
    )

    $nomesTeste = @($Nome)

    if ($NomesValidacao -and $NomesValidacao.Count -gt 0) {
        $nomesTeste = @($NomesValidacao)
    }

    foreach ($nomeTeste in $nomesTeste) {
        if (Test-ProgramaInstalado $nomeTeste) {
            Write-Host "$Nome ja instalado." -ForegroundColor Yellow
            return $true
        }
    }

    $msi = Join-Path $TempPath "$Nome.msi"

    if (-not (Baixar-ArquivoPublico -Url $Url -Destino $msi -Nome $Nome)) {
        return $false
    }

    Write-Host "Instalando $Nome..." -NoNewline

    try {
        $argumentos = "/i `"$msi`" /qn /norestart $ArgumentosExtras"
        $processo = Start-Process msiexec.exe `
            -ArgumentList $argumentos `
            -Wait `
            -PassThru

        if ($processo.ExitCode -notin @(0, 3010, 1641)) {
            Write-Host "  ERRO" -ForegroundColor Red
            Mostrar-Detalhe "msiexec retornou codigo $($processo.ExitCode)."
            return $false
        }

        Start-Sleep -Seconds 2

        foreach ($nomeTeste in $nomesTeste) {
            if (Test-ProgramaInstalado $nomeTeste) {
                $reboot = if ($processo.ExitCode -in @(3010, 1641)) { " (reinicio pendente)" } else { "" }
                Write-Host "  OK$reboot" -ForegroundColor Green
                return $true
            }
        }

        Write-Host "  ERRO" -ForegroundColor Red
        Mostrar-Detalhe "Instalador terminou sem erro, mas $Nome nao foi encontrado no registro."
        return $false
    }
    catch {
        Write-Host "  ERRO" -ForegroundColor Red
        Mostrar-Detalhe $_.Exception.Message
        return $false
    }
}

function Test-DependenciasOdbcInstaladas {
    $nativeClientOk = Test-ProgramaInstalado "SQL Server Native Client"
    $odbc17Ok = Test-ProgramaInstalado "ODBC Driver 17 for SQL Server"

    return [PSCustomObject]@{
        NativeClient = $nativeClientOk
        Odbc17       = $odbc17Ok
        OK           = ($nativeClientOk -and $odbc17Ok)
    }
}

function Instalar-DependenciasOdbc {
    param([string]$TempPath)

    if ([string]::IsNullOrWhiteSpace($TempPath)) {
        $TempPath = Join-Path $env:TEMP "nexus_odbc"
    }

    if (-not (Test-Path $TempPath)) {
        New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
    }

    Write-Host "Verificando dependencias ODBC..." -ForegroundColor Cyan
    Write-Host ""

    $nativeClientOk = Instalar-MSI `
        -Nome "SQL Server Native Client" `
        -Url "https://cloud.maxdata.com.br/s/zK2GTCSqXq9C8Kk/download/sqlnclix64.msi" `
        -TempPath $TempPath `
        -ArgumentosExtras "IACCEPTSQLNCLILICENSETERMS=YES" `
        -NomesValidacao @("SQL Server Native Client")

    $odbc17Ok = Instalar-MSI `
        -Nome "ODBC Driver 17 for SQL Server" `
        -Url "https://cloud.maxdata.com.br/s/HbCkKA39Jq4rSRo/download/msodbcsqlx64.msi" `
        -TempPath $TempPath `
        -ArgumentosExtras "IACCEPTMSODBCSQLLICENSETERMS=YES" `
        -NomesValidacao @("ODBC Driver 17 for SQL Server")

    $status = Test-DependenciasOdbcInstaladas

    if (-not ($nativeClientOk -and $odbc17Ok -and $status.OK)) {
        throw "Falha ao instalar dependencias ODBC. Native Client: $($status.NativeClient). ODBC 17: $($status.Odbc17)."
    }

    Write-Host ""
    Mostrar-Sucesso "Dependencias ODBC instaladas/validadas."
    return $true
}

Mostrar-TituloNexus "TESTE TEMP - ODBC"

$tempPath = Join-Path $env:TEMP "nexus_odbc"

try {
    Instalar-DependenciasOdbc -TempPath $tempPath | Out-Null
}
catch {
    Write-Host ""
    Mostrar-Erro "Falha no teste ODBC."
    Mostrar-Detalhe $_.Exception.Message
}
finally {
    try {
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {}
}

Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
