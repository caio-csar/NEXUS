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

$Base = "/UPLOADS"

# ============================================
# MENU
# ============================================

while ($true) {

    Mostrar-TituloNexus "CLOUD"

    Write-Host " 1 - Enviar arquivos"
    Write-Host " 2 - Baixar arquivos"
    Write-Host ""
    Write-Host " 0 - Voltar"
    Write-Host ""

    $op = (
        Read-Host "Escolha"
    ).Trim()

    switch ($op) {

        # ====================================
        # UPLOAD
        # ====================================

        "1" {

            Mostrar-TituloNexus "UPLOAD"

            $arquivos = Selecionar-ArquivoNexus `
                -Titulo "Selecione os arquivos" `
                -Multiselect

            if (-not $arquivos) {
                continue
            }

            Write-Host ""
            Write-Host "Arquivos selecionados:"
            Write-Host ""

            foreach ($a in $arquivos) {
                Write-Host " - $(Split-Path $a -Leaf)"
            }

            Write-Host ""

            $nomePasta = (
                Read-Host "Nome da pasta no cloud"
            ).Trim()

            if (
                [string]::IsNullOrWhiteSpace(
                    $nomePasta
                )
            ) {
                Mostrar-Aviso "Nome invalido."
                continue
            }

            $remotePath = "$Base/$nomePasta"

            Criar-PastaWebDav `
                -Url "$Cloud$remotePath" `
                -Headers $Headers `
                -Credencial $Cred | Out-Null

            Write-Host ""

            if (-not (
                Confirmar-Acao "Confirmar upload"
            )) {
                continue
            }

            $timer = Iniciar-TimerNexus

            $ProgressPreference = 'SilentlyContinue'

            $ok = 0
            $erro = 0

            foreach ($arquivo in $arquivos) {

                $nome = Split-Path `
                    $arquivo `
                    -Leaf

                $url = "$Cloud$remotePath/$nome"

                if (
                    Upload-NexusArquivo `
                        -Url $url `
                        -Arquivo $arquivo `
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

            Mostrar-Sucesso "Upload concluido."

            Write-Host "Enviados: $ok" -ForegroundColor Green
            Write-Host "Falhas: $erro" -ForegroundColor Yellow

            Mostrar-TempoExecucao `
                -Inicio $timer `
                -Nome "upload"

            Pausar-Nexus `
                -ChamadoPeloCore $ChamadoPeloCore
        }

        # ====================================
        # DOWNLOAD
        # ====================================

        "2" {

            Mostrar-TituloNexus "DOWNLOAD"

            $destino = Selecionar-PastaNexus `
                -Titulo "Selecione onde salvar"

            if (-not $destino) {
                continue
            }

            $pastas = @(
                Get-NexusCloudItemsComTipo `
                    -Cloud $Cloud `
                    -Path $Base `
                    -Credencial $Cred
            )

            $pastas = @(
                $pastas |
                Where-Object {
                    $_.Tipo -eq "PASTA"
                } |
                Sort-Object Nome
            )

            if ($pastas.Count -eq 0) {

                Mostrar-Aviso "Nenhuma pasta encontrada."

                Pausar-Nexus `
                    -ChamadoPeloCore $ChamadoPeloCore

                continue
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

            $escolha = (
                Read-Host "Escolha"
            ).Trim()

            if ($escolha -eq "0") {
                continue
            }

            if ($escolha -notmatch '^\d+$') {
                continue
            }

            $idx = [int]$escolha - 1

            if (
                $idx -lt 0 -or
                $idx -ge $pastas.Count
            ) {
                continue
            }

            $pasta = $pastas[$idx].Nome

            $remotePath = "$Base/$pasta"

            $arquivos = @(
                Get-NexusCloudItemsComTipo `
                    -Cloud $Cloud `
                    -Path $remotePath `
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

                continue
            }

            Write-Host ""
            Write-Host "Arquivos encontrados:"
            Write-Host ""

            foreach ($a in $arquivos) {
                Write-Host " - $($a.Nome)"
            }

            Write-Host ""

            if (-not (
                Confirmar-Acao "Confirmar download"
            )) {
                continue
            }

            $timer = Iniciar-TimerNexus

            $ProgressPreference = 'SilentlyContinue'

            $ok = 0
            $erro = 0

            foreach ($arq in $arquivos) {

                $nome = $arq.Nome

                $url = "$Cloud$remotePath/$nome"

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
        }

        # ====================================
        # VOLTAR
        # ====================================

        "0" {
            return
        }
    }
}