[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# ============================================
# NEXUS CORE
# ============================================

# --------------------------------------------
# ADMIN
# --------------------------------------------

if (-not (
    (New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
)) {
    Write-Host "Execute como Administrador." -ForegroundColor Red
    return
}

# --------------------------------------------
# CONFIG
# --------------------------------------------

$script:Cloud = "https://cloud.maxdata.com.br/remote.php/webdav"

$script:NexusRawBase = "https://raw.githubusercontent.com/caio-csar/NEXUS/main"

# --------------------------------------------
# CREDENCIAIS
# --------------------------------------------

$script:Usuario = Read-Host "Usuario"
$script:Senha = Read-Host "Senha" -AsSecureString

$script:Cred = New-Object System.Management.Automation.PSCredential(
    $script:Usuario,
    $script:Senha
)

$script:SenhaPlain = $script:Cred.GetNetworkCredential().Password

# --------------------------------------------
# VALIDAR CREDENCIAIS
# --------------------------------------------

Write-Host ""
Write-Host "Verificando credenciais..." -ForegroundColor Cyan

try {

    $plain = $script:Cred.GetNetworkCredential().Password

    $basic = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes(
            "$($script:Usuario):$plain"
        )
    )

    $req = [System.Net.HttpWebRequest]::Create(
        $script:Cloud
    )

    $req.Method = "HEAD"

    $req.Headers.Add(
        "Authorization",
        "Basic $basic"
    )

    $req.Timeout = 10000

    $resp = $req.GetResponse()

    $resp.Close()

    Write-Host "Credenciais validas." -ForegroundColor Green
}
catch [System.Net.WebException] {

    $status = [int]$_.Exception.Response.StatusCode

    if ($status -eq 401) {

        Write-Host "Usuario ou senha incorretos." -ForegroundColor Red

        Read-Host "`nENTER para sair"

        return
    }

    Write-Host "Credenciais aceitas." -ForegroundColor Green
}
catch {

    Write-Host "Aviso ao validar credenciais." -ForegroundColor Yellow

    Write-Host $_.Exception.Message -ForegroundColor DarkGray
}

# --------------------------------------------
# SHARED CACHE
# --------------------------------------------

$script:SharedPath = $null

# --------------------------------------------
# MODULOS
# --------------------------------------------

$Modulos = @(

    @{
        Id = 1
        Nome = "Instalar / Atualizar"
        Script = "modulo_instalador.ps1"
    }

    @{
        Id = 2
        Nome = "Pastas Atualizadas"
        Script = "modulo_pastas_atualizadas.ps1"
    }

    @{
        Id = 3
        Nome = "Cloud"
        Script = "modulo_upload.ps1"
    }

)

# --------------------------------------------
# FUNCOES
# --------------------------------------------

function Baixar-ArquivoCore {

    param(
        [string]$NomeArquivo
    )

    $temp = Join-Path $env:TEMP $NomeArquivo

    $url = "$script:NexusRawBase/$NomeArquivo"

    $maxTentativas = 3

    for ($tentativa = 1; $tentativa -le $maxTentativas; $tentativa++) {

        try {

            Invoke-WebRequest `
                -Uri $url `
                -OutFile $temp `
                -UseBasicParsing `
                -ErrorAction Stop

            if (Test-Path $temp) {
                return $temp
            }

        }
        catch {

            if ($tentativa -lt $maxTentativas) {

                Write-Host "Tentativa $tentativa falhou ao baixar $NomeArquivo." -ForegroundColor Yellow

                Start-Sleep -Seconds 2
            }
            else {

                Write-Host "Falha ao baixar $NomeArquivo." -ForegroundColor Red

                Write-Host $_.Exception.Message -ForegroundColor DarkGray
            }
        }
    }

    return $null
}

function Obter-SharedPath {

    if (
        $script:SharedPath -and
        (Test-Path $script:SharedPath)
    ) {
        return $script:SharedPath
    }

    $shared = Baixar-ArquivoCore "NEXUS_SHARED.ps1"

    $script:SharedPath = $shared

    return $shared
}

function Executar-Modulo {

    param($Modulo)

    Clear-Host

    Write-Host "Carregando $($Modulo.Nome)..." -ForegroundColor Cyan

    $shared = Obter-SharedPath

    if (-not $shared) {

        Read-Host "`nENTER para voltar"

        return
    }

    $arquivo = Baixar-ArquivoCore $Modulo.Script

    if (-not $arquivo) {

        Read-Host "`nENTER para voltar"

        return
    }

    try {

        powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $arquivo `
            -Usuario $script:Usuario `
            -SenhaPlain $script:SenhaPlain `
            -ChamadoPeloCore 1
    }
    catch {

        Write-Host "Erro executando modulo." -ForegroundColor Red

        Write-Host $_.Exception.Message -ForegroundColor DarkGray
    }
    finally {

        Remove-Item `
            $arquivo `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Read-Host "`nENTER para voltar"
}

# --------------------------------------------
# MENU
# --------------------------------------------

while ($true) {

    Clear-Host

    Write-Host ""
    Write-Host "========= NEXUS =========" -ForegroundColor Cyan
    Write-Host ""

    foreach ($m in $Modulos) {

        Write-Host " $($m.Id) - $($m.Nome)"
    }

    Write-Host ""
    Write-Host " 0 - Sair"
    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    if ($op -eq "0") {
        break
    }

    if ($op -notmatch '^\d+$') {
        continue
    }

    $sel = $Modulos | Where-Object {
        $_.Id -eq [int]$op
    }

    if ($sel) {
        Executar-Modulo $sel
    }
}

if (
    $script:SharedPath -and
    (Test-Path $script:SharedPath)
) {

    Remove-Item `
        $script:SharedPath `
        -Force `
        -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Encerrado." -ForegroundColor Cyan