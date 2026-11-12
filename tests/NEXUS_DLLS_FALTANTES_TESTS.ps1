$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$utilFile = Join-Path $repo "modulo_utilitarios.ps1"
$scriptFile = Join-Path $repo "Scripts_Uteis/Completar-DLLs.ps1"
$installerFile = Join-Path $repo "modulo_instalador.ps1"

$util = Get-Content -LiteralPath $utilFile -Raw
$scriptText = Get-Content -LiteralPath $scriptFile -Raw
$installer = Get-Content -LiteralPath $installerFile -Raw

foreach ($required in @(
    '[8] Inserir DLLs faltantes',
    '"8" { Inserir-DllsFaltantesNexus; Pausar-UtilitarioNexus -Nome "completar DLLs" }',
    'Scripts_Uteis/Completar-DLLs.ps1',
    'Test-ArquivoRarNexus',
    'Obter-7ZipNexus'
)) {
    if (-not $util.Contains($required)) { throw "Falta na integracao: $required" }
}

$sourceUrl = 'https://cloud.maxdata.com.br/s/5MaMq2RJ5fzYEbA/download/DLLS.rar'
if (-not $util.Contains($sourceUrl) -or -not $installer.Contains($sourceUrl)) {
    throw 'O utilitario deve usar o mesmo DLLS.rar do instalador NEXUS.'
}
if (-not $scriptText.Contains('[System.IO.File]::Copy($arquivo.FullName, $destinoArquivo, $false)')) {
    throw 'A copia deve bloquear sobrescrita mesmo em condicao de corrida.'
}

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw "Script de DLLs com erro de sintaxe: $($errors | Out-String)" }

$utilTokens = $null
$utilErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($utilFile, [ref]$utilTokens, [ref]$utilErrors) | Out-Null
if ($utilErrors.Count -gt 0) { throw "Utilitarios com erro de sintaxe: $($utilErrors | Out-String)" }

$funcoes = @($ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Copiar-DllsFaltantesNexus'
}, $true))
if ($funcoes.Count -ne 1) { throw 'Funcao de copia nao encontrada.' }
. ([scriptblock]::Create($funcoes[0].Extent.Text))

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("NEXUS_TEST_DLLS_" + [guid]::NewGuid().ToString("N"))
$origem = Join-Path $testRoot "extraido"
$destino = Join-Path $testRoot "sistema"
try {
    $srcNested = Join-Path $origem "lib"
    $dstNested = Join-Path $destino "lib"
    [void][System.IO.Directory]::CreateDirectory($srcNested)
    [void][System.IO.Directory]::CreateDirectory($dstNested)
    [System.IO.File]::WriteAllText((Join-Path $srcNested 'existente.dll'), 'DLL ANTIGA')
    [System.IO.File]::WriteAllText((Join-Path $srcNested 'faltante.dll'), 'DLL NOVA')
    [System.IO.File]::WriteAllText((Join-Path $origem 'outra.DLL'), 'DLL MAIUSCULA')
    [System.IO.File]::WriteAllText((Join-Path $origem 'nao_incluir.txt'), 'TEXTO')
    [System.IO.File]::WriteAllText((Join-Path $dstNested 'existente.dll'), 'DLL ORIGINAL')

    $primeiro = Copiar-DllsFaltantesNexus -Origem $origem -Destino $destino
    if ($primeiro.Inseridas -ne 2 -or $primeiro.Existentes -ne 1 -or
        $primeiro.Falhas -ne 0 -or $primeiro.Total -ne 3) {
        throw "Primeira execucao incorreta: $($primeiro | ConvertTo-Json -Compress)"
    }
    if ([System.IO.File]::ReadAllText((Join-Path $dstNested 'existente.dll')) -ne 'DLL ORIGINAL') {
        throw 'DLL existente foi sobrescrita.'
    }
    if ([System.IO.File]::ReadAllText((Join-Path $dstNested 'faltante.dll')) -ne 'DLL NOVA') {
        throw 'DLL ausente nao foi inserida no caminho correto.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $destino 'outra.DLL'))) {
        throw 'DLL com extensao maiuscula nao foi inserida.'
    }
    if (Test-Path -LiteralPath (Join-Path $destino 'nao_incluir.txt')) {
        throw 'O utilitario copiou arquivo que nao e DLL.'
    }

    $segundo = Copiar-DllsFaltantesNexus -Origem $origem -Destino $destino
    if ($segundo.Inseridas -ne 0 -or $segundo.Existentes -ne 3 -or $segundo.Falhas -ne 0) {
        throw "Segunda execucao deveria detectar todas as DLLs existentes: $($segundo | ConvertTo-Json -Compress)"
    }

    Write-Host 'NEXUS_DLLS_FALTANTES_TESTS OK' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
