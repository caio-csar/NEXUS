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

while ($true) {
    Mostrar-TituloNexus "UTILITARIOS"

    Write-Host "1 - Corrigir WMI"
    Write-Host "2 - Instalar/Verificar ODBC"
    Write-Host "3 - Abrir Pasta do Sistema"
    Write-Host "0 - Voltar"
    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    switch ($op) {
        "1" { Corrigir-WmiNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "2" { Instalar-VerificarOdbcNexus }
        "3" { Abrir-PastaSistemaNexus; Read-Host "`nENTER para voltar" | Out-Null }
        "0" { return }
        default { continue }
    }
}
