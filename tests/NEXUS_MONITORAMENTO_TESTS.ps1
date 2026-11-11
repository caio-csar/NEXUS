$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$corePath = Join-Path $repo "NEXUS_CORE.ps1"
$configPath = Join-Path $repo "monitoramento/config.json"

$erros = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $corePath,
    [ref]$tokens,
    [ref]$erros
) | Out-Null

if ($erros.Count -gt 0) {
    throw "NEXUS_CORE.ps1 contem erros de sintaxe: $($erros | Out-String)"
}

$core = Get-Content -LiteralPath $corePath -Raw
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

if ($null -eq $config.enabled -or $config.enabled -isnot [bool]) {
    throw "Monitoramento deve informar enabled booleano."
}
if (-not ([string]$config.endpoint).StartsWith("https://")) {
    throw "Monitoramento deve usar endpoint HTTPS."
}

$esperado = @(
    'function Registrar-AcessoNexus',
    'Registrar-AcessoNexus',
    'monitoramento/config.json',
    '-TimeoutSec 2',
    'data_hora_cliente',
    'usuario_nexus',
    'computador',
    'usuario_windows',
    'sistema_operacional',
    'if ($config.enabled -ne $true)',
    'catch {',
    'Mostrar-MenuPrincipalNexus',
    '[6] Utilitarios'
)

foreach ($item in $esperado) {
    if (-not $core.Contains($item)) {
        throw "Integracao incompleta: $item"
    }
}

if ($core.IndexOf("Registrar-AcessoNexus") -gt $core.IndexOf("# SHARED CACHE")) {
    throw "O registro deve ser isolado do ciclo dos modulos."
}

Write-Host "NEXUS_MONITORAMENTO_TESTS OK" -ForegroundColor Green
