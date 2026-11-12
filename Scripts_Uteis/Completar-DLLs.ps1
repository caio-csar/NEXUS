param(
    [Parameter(Mandatory = $true)][string]$PastaSistema,
    [Parameter(Mandatory = $true)][string]$ArquivoRar,
    [Parameter(Mandatory = $true)][string]$SevenZipPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Copia somente DLLs ausentes, sem alterar arquivos existentes.
# Mantem exatamente os caminhos relativos extraidos do mesmo DLLS.rar usado pelo instalador.
function Copiar-DllsFaltantesNexus {
    param(
        [Parameter(Mandatory = $true)][string]$Origem,
        [Parameter(Mandatory = $true)][string]$Destino
    )

    if (-not (Test-Path -LiteralPath $Origem -PathType Container)) {
        throw 'Pasta de extracao das DLLs nao encontrada.'
    }
    if (-not (Test-Path -LiteralPath $Destino -PathType Container)) {
        throw 'Pasta do sistema nao encontrada.'
    }

    $baseOrigem = [System.IO.Path]::GetFullPath($Origem).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    $baseDestino = [System.IO.Path]::GetFullPath($Destino).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar

    $arquivos = @(Get-ChildItem -LiteralPath $Origem -File -Recurse -ErrorAction Stop |
        Where-Object { $_.Extension -ieq '.dll' })

    if ($arquivos.Count -eq 0) {
        throw 'Nenhuma DLL foi encontrada no pacote. Nenhum arquivo foi modificado.'
    }

    $incluidas = 0
    $existentes = 0
    $falhas = 0

    foreach ($arquivo in $arquivos) {
        try {
            if (($arquivo.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw ('Arquivo de origem nao permitido: ' + $arquivo.Name)
            }

            $relativo = $arquivo.FullName.Substring($baseOrigem.Length)
            $destinoArquivo = [System.IO.Path]::GetFullPath((Join-Path $Destino $relativo))
            if (-not $destinoArquivo.StartsWith(
                $baseDestino, [System.StringComparison]::OrdinalIgnoreCase
            )) {
                throw ('Caminho invalido no pacote: ' + $relativo)
            }

            if (Test-Path -LiteralPath $destinoArquivo -PathType Leaf) {
                $existentes++
                continue
            }

            $pastaAlvo = [System.IO.Path]::GetDirectoryName($destinoArquivo)
            [void][System.IO.Directory]::CreateDirectory($pastaAlvo)

            # overwrite=false: protegido mesmo se outro processo criar a DLL entre as checagens.
            [System.IO.File]::Copy($arquivo.FullName, $destinoArquivo, $false)
            $incluidas++
        }
        catch [System.IO.IOException] {
            if (Test-Path -LiteralPath $destinoArquivo -PathType Leaf) {
                $existentes++
            } else {
                $falhas++
            }
        }
        catch {
            $falhas++
        }
    }

    return [pscustomobject]@{
        Inseridas  = $incluidas
        Existentes = $existentes
        Falhas     = $falhas
        Total      = $arquivos.Count
    }
}

# EXECUCAO: mantida separada para os testes validarem a copia sem baixar o pacote.
$extraidos = Join-Path $env:TEMP ("NEXUS_DLLS_EXTRACAO_" + [guid]::NewGuid().ToString('N'))

try {
    if (-not (Test-Path -LiteralPath $PastaSistema -PathType Container)) {
        throw 'A pasta do sistema selecionada nao existe.'
    }
    if (-not (Test-Path -LiteralPath $ArquivoRar -PathType Leaf)) {
        throw 'Pacote de DLLs nao encontrado.'
    }
    if (-not (Test-Path -LiteralPath $SevenZipPath -PathType Leaf)) {
        throw '7-Zip nao encontrado.'
    }

    [void][System.IO.Directory]::CreateDirectory($extraidos)

    & $SevenZipPath x $ArquivoRar "-o$extraidos" -y -bd 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw ('Falha ao extrair o pacote de DLLs. Codigo do 7-Zip: ' + $LASTEXITCODE)
    }

    $resultado = Copiar-DllsFaltantesNexus -Origem $extraidos -Destino $PastaSistema

    if ($resultado.Falhas -gt 0) {
        throw ("$($resultado.Falhas) DLLs nao puderam ser inseridas. $($resultado.Inseridas) foram inseridas.")
    }

    if ($resultado.Inseridas -gt 0) {
        Write-Host ("{0} DLLs faltantes foram inseridas." -f $resultado.Inseridas) -ForegroundColor Green
    }
    else {
        Write-Host 'A pasta do sistema ja possui todas as DLLs.' -ForegroundColor Green
    }
}
catch {
    Write-Host ('Falha ao completar DLLs: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    Remove-Item -LiteralPath $extraidos -Recurse -Force -ErrorAction SilentlyContinue
}
