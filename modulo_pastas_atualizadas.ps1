param(
    [string]$Usuario,
    [string]$SenhaPlain,
    [int]$ChamadoPeloCore = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# ============================================
# SHARED
# ============================================

$shared = Join-Path $PSScriptRoot "NEXUS_SHARED.ps1"

if (Test-Path $shared) {
    . $shared
}
else {
    Write-Host "NEXUS_SHARED.ps1 nao encontrado." -ForegroundColor Red
    return
}

# ============================================
# CONFIG
# ============================================

$Cloud = "https://cloud.maxdata.com.br/remote.php/webdav"

$Cred = Nova-CredencialNexus `
    -Usuario $Usuario `
    -SenhaPlain $SenhaPlain

$Headers = New-NexusBasicAuthHeader `
    -Usuario $Cred.UserName `
    -Credencial $Cred

$Base = "/PASTAS_ATUALIZADAS"

# ============================================
# EXECUCAO
# ============================================

Mostrar-TituloNexus "PASTAS ATUALIZADAS"

$destino = Selecionar-PastaNexus `
    -Titulo "Selecione onde salvar"

if (-not $destino) {

    Mostrar-Aviso "Nenhuma pasta selecionada."

    Pausar-Nexus `
        -ChamadoPeloCore $ChamadoPeloCore

    return
}

$itens = @(
    Get-NexusCloudItemsComTipo `
        -Cloud $Cloud `
        -Path $Base `
        -Credencial $Cred
)

if ($itens.Count -eq 0) {

    Mostrar-Erro "Nenhuma pasta encontrada."

    Pausar-Nexus `
        -ChamadoPeloCore $ChamadoPeloCore

    return
}

$pastas = @(
    $itens |
    Where-Object {
        $_.Tipo -eq "PASTA"
    } |
    Sort-Object Nome
)

if ($pastas.Count -eq 0) {

    Mostrar-Erro "Nenhuma pasta disponivel."

    Pausar-Nexus `
        -ChamadoPeloCore $ChamadoPeloCore

    return
}

Write-Host "Pastas disponiveis:"
Write-Host ""

for ($i = 0; $i -lt $pastas.Count; $i++) {

    Write-Host (
        " {0} - {1}" -f
        ($i + 1),
        $pastas[$i].Nome
    )
}

Write-Host ""
Write-Host "0 - Voltar"
Write-Host ""

$op = (
    Read-Host "Escolha"
).Trim()

if ($op -eq "0") {
    return
}

if ($op -notmatch '^\d+$') {

    Mostrar-Erro "Opcao invalida."

    Pausar-Nexus `
        -ChamadoPeloCore $ChamadoPeloCore

    return
}

$idx = [int]$op - 1

if (
    $idx -lt 0 -or
    $idx -ge $pastas.Count
) {

    Mostrar-Erro "Opcao invalida."

    Pausar-Nexus `
        -ChamadoPeloCore $ChamadoPeloCore

    return
}

$pasta = $pastas[$idx].Nome

Write-Host ""
Write-Host "Pasta selecionada: $pasta" -ForegroundColor Cyan

Write-Host ""

if (-not (
    Confirmar-Acao "Confirmar download"
)) {
    return
}

$timer = Iniciar-TimerNexus

$pathRemoto = "$Base/$pasta"

$arquivos = @(
    Get-NexusCloudItemsComTipo `
        -Cloud $Cloud `
        -Path $pathRemoto `
        -Credencial $Cred
)

$arquivos = @(
    $arquivos |
    Where-Object {
        $_.Tipo -eq "ARQUIVO"
    }
)

if ($arquivos.Count -eq 0) {

    Mostrar-Aviso "Nenhum arquivo encontrado."

    Pausar-Nexus `
        -ChamadoPeloCore $ChamadoPeloCore

    return
}

$ProgressPreference = 'SilentlyContinue'

$ok = 0
$erro = 0

foreach ($arq in $arquivos) {

    $nome = $arq.Nome

    $url = "$Cloud$pathRemoto/$nome"

    $saida = Join-Path `
        $destino `
        $nome

    if (
        Download-NexusArquivo `
            -Url $url `
            -Destino $saida `
            -Nome $nome `
            -Headers $Headers
    ) {
        $ok++
    }
    else {
        $erro++
    }
}

$ProgressPreference = 'Continue'

Write-Host ""

Mostrar-Sucesso "Download concluido."

Write-Host "Baixados: $ok" -ForegroundColor Green
Write-Host "Falhas: $erro" -ForegroundColor Yellow

Mostrar-TempoExecucao `
    -Inicio $timer `
    -Nome "download"

Abrir-PastaNexus $destino

Pausar-Nexus `
    -ChamadoPeloCore $ChamadoPeloCore