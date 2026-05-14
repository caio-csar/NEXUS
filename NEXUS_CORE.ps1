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
$script:PastaModulos = "/NEXUS"

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
        [Text.Encoding]::ASCII.GetBytes("$($script:Usuario):$plain")
    )

    $req = [System.Net.HttpWebRequest]::Create("$script:Cloud/NEXUS")
    $req.Method = "HEAD"
    $req.Headers.Add("Authorization", "Basic $basic")
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

    # Qualquer outro status (403, 404, etc.) significa que o servidor respondeu:
    # as credenciais foram aceitas. A pasta pode apenas nao existir neste path.
    Write-Host "Credenciais aceitas." -ForegroundColor Green
}
catch {
    Write-Host "Aviso: nao foi possivel verificar credenciais ($($_.Exception.Message))." -ForegroundColor Yellow
    Write-Host "Continuando..." -ForegroundColor Yellow
}

# --------------------------------------------
# SHARED CACHE
# --------------------------------------------

# O NEXUS_SHARED.ps1 e baixado uma unica vez por sessao e reutilizado.
# Evita re-download a cada modulo executado.
$script:SharedPath = $null

# --------------------------------------------
# MODULOS
# --------------------------------------------

$Modulos = @(
    @{ Id = 1; Nome = "Instalar Sistema";              Script = "modulo_instalador.ps1" },
    @{ Id = 2; Nome = "Atualizar Sistema";             Script = "modulo_atualizar_sistema.ps1" },
    @{ Id = 3; Nome = "Baixar Ultima Versao";          Script = "modulo_ultima_versao.ps1" },
    @{ Id = 4; Nome = "Baixar Pastas Atualizadas";     Script = "modulo_pastas_atualizadas.ps1" },
    @{ Id = 5; Nome = "Backup para Cloud";             Script = "modulo_backup.ps1" },
    @{ Id = 6; Nome = "Enviar Arquivos para Cloud";    Script = "modulo_upload.ps1" },
    @{ Id = 7; Nome = "Explorar Utilitarios";          Script = "modulo_explorar_uteis.ps1" }
)

# --------------------------------------------
# FUNCOES
# --------------------------------------------

function New-CoreHeaders {
    $plain = $script:Cred.GetNetworkCredential().Password
    $basic = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes("$($script:Usuario):$plain")
    )

    return @{
        Authorization = "Basic $basic"
    }
}

function Baixar-ArquivoCore {
    param(
        [string]$NomeArquivo
    )

    $temp = Join-Path $env:TEMP $NomeArquivo
    $url  = "$script:Cloud$script:PastaModulos/$NomeArquivo"
    $headers = New-CoreHeaders
    $maxTentativas = 3

    for ($tentativa = 1; $tentativa -le $maxTentativas; $tentativa++) {
        try {
            Invoke-WebRequest `
                -Uri $url `
                -OutFile $temp `
                -Headers $headers `
                -UseBasicParsing `
                -ErrorAction Stop

            if (Test-Path $temp) {
                return $temp
            }
        }
        catch {
            if ($tentativa -lt $maxTentativas) {
                Write-Host "Tentativa $tentativa falhou ao baixar $NomeArquivo. Aguardando..." -ForegroundColor Yellow
                Start-Sleep -Seconds (2 * $tentativa)
            }
            else {
                Write-Host "Falha ao baixar: $NomeArquivo" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor DarkGray
            }
        }
    }

    return $null
}

function Obter-SharedPath {
    # Reutiliza o shared ja baixado na sessao.
    # Baixa novamente apenas se ainda nao existe ou foi removido externamente.
    if ($script:SharedPath -and (Test-Path $script:SharedPath)) {
        return $script:SharedPath
    }

    $caminho = Baixar-ArquivoCore "NEXUS_SHARED.ps1"
    $script:SharedPath = $caminho
    return $caminho
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
        # Garante limpeza do modulo mesmo em interrupcao abrupta.
        # O shared NAO e removido aqui — e reutilizado pela sessao.
        Remove-Item $arquivo -Force -ErrorAction SilentlyContinue
    }

    Read-Host "`nENTER para voltar"
}

# --------------------------------------------
# MENU
# --------------------------------------------

while ($true) {
    Clear-Host

    Write-Host "========= NEXUS =========" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1 - Instalar Sistema"
    Write-Host "2 - Atualizar Sistema"
    Write-Host "3 - Baixar Ultima Versao"
    Write-Host "4 - Baixar Pastas Atualizadas"
    Write-Host "5 - Backup para Cloud"
    Write-Host "6 - Enviar Arquivos para Cloud"
    Write-Host "7 - Explorar Utilitarios"
    Write-Host "0 - Sair"
    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    if ($op -eq "0") {
        break
    }

    if ($op -notmatch '^\d+$') {
        continue
    }

    $sel = $Modulos | Where-Object { $_.Id -eq [int]$op }

    if ($sel) {
        Executar-Modulo $sel
    }
}

# Limpeza final ao encerrar a sessao
if ($script:SharedPath -and (Test-Path $script:SharedPath)) {
    Remove-Item $script:SharedPath -Force -ErrorAction SilentlyContinue
}



Write-Host "Encerrado." -ForegroundColor Cyan
