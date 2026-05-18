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
# MENU
# ============================================

while ($true) {

    Clear-Host

    Write-Host ""
    Write-Host "===== INSTALAR / ATUALIZAR =====" -ForegroundColor Cyan
    Write-Host ""

    Write-Host " 1 - Instalacao"
    Write-Host " 2 - Atualizacao"
    Write-Host ""
    Write-Host " 0 - Voltar"
    Write-Host ""

    $op = (Read-Host "Escolha").Trim()

    switch ($op) {

        "1" {

            Clear-Host

            Write-Host ""
            Write-Host "===== INSTALACAO =====" -ForegroundColor Cyan
            Write-Host ""

            $drives = Get-PSDrive `
                -PSProvider FileSystem |
                Sort-Object Name

            Write-Host "Discos disponiveis:"
            Write-Host ""

            for ($i = 0; $i -lt $drives.Count; $i++) {

                Write-Host (
                    " {0} - {1}\" -f
                    ($i + 1),
                    $drives[$i].Name
                )
            }

            Write-Host ""

            $diskOp = Read-Host "Selecione o disco"

            if ($diskOp -notmatch '^\d+$') {
                continue
            }

            $idx = [int]$diskOp - 1

            if (
                $idx -lt 0 -or
                $idx -ge $drives.Count
            ) {
                continue
            }

            $drive = "$($drives[$idx].Name):\"

            Write-Host ""
            Write-Host "Nome da pasta [ENTER = MAX]" -ForegroundColor Green

            $nomePasta = (
                Read-Host "Pasta"
            ).Trim()

            if (
                [string]::IsNullOrWhiteSpace(
                    $nomePasta
                )
            ) {
                $nomePasta = "MAX"
            }

            $basePath = Join-Path `
                $drive `
                $nomePasta

            Write-Host ""
            Write-Host "Estrutura:"
            Write-Host ""

            Write-Host " $basePath"
            Write-Host " $basePath\_UTEIS"
            Write-Host " $basePath\DADOS"
            Write-Host " $basePath\BACKUP"

            Write-Host ""

            $confirma = (
                Read-Host "Confirmar? [S/N]"
            ).Trim().ToUpper()

            if ($confirma -ne "S") {
                continue
            }

            New-Item `
                -ItemType Directory `
                -Path $basePath `
                -Force | Out-Null

            New-Item `
                -ItemType Directory `
                -Path "$basePath\_UTEIS" `
                -Force | Out-Null

            New-Item `
                -ItemType Directory `
                -Path "$basePath\DADOS" `
                -Force | Out-Null

            New-Item `
                -ItemType Directory `
                -Path "$basePath\BACKUP" `
                -Force | Out-Null

            Write-Host ""
            Write-Host "Estrutura pronta." -ForegroundColor Green

            Read-Host "`nENTER"
        }

        "2" {

            powershell.exe `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File (
                    Join-Path `
                    $PSScriptRoot `
                    "modulo_atualizar_sistema.ps1"
                ) `
                -Usuario $Usuario `
                -SenhaPlain $SenhaPlain `
                -ChamadoPeloCore 1
        }

        "0" {
            return
        }
    }
}