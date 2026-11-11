$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$arquivo = Join-Path $repo "Scripts_Uteis/Instalar-ICP-Brasil.ps1"

if (-not (Test-Path -LiteralPath $arquivo)) {
    throw "Atualizador ICP-Brasil nao encontrado."
}

$tokens = $null
$erros = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $arquivo, [ref]$tokens, [ref]$erros
) | Out-Null

if ($erros.Count -gt 0) {
    throw "Atualizador ICP-Brasil com erros de sintaxe: $($erros | Out-String)"
}

$conteudo = Get-Content -LiteralPath $arquivo -Raw

$itens = @(
    'https://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil/ACcompactado.zip',
    'https://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil/hashsha512.txt',
    '[Net.SecurityProtocolType]::Tls12',
    '-Algorithm SHA512',
    'if ($hashEsperado -ne $hashCalculado)',
    'Expand-Archive',
    'X509BasicConstraintsExtension',
    'CertificateAuthority',
    'Cert:\LocalMachine\',
    "destino = 'Root'",
    "destino = 'CA'",
    'certutil.exe',
    'if (-not (Test-Path -LiteralPath $caminhoStore))',
    'Start-Transcript',
    'Stop-Transcript',
    'instalacao.log',
    'resultado.csv',
    'Export-Csv',
    'exit $codigoSaida'
)

foreach ($item in $itens) {
    if (-not $conteudo.Contains($item)) {
        throw "Etapa obrigatoria ausente no atualizador ICP-Brasil: $item"
    }
}

if ($conteudo.Contains('certutil -delstore') -or $conteudo.Contains('Remove-Item Cert:\')) {
    throw "O atualizador ICP-Brasil nao deve remover certificados instalados."
}

Write-Host "NEXUS_ICP_BRASIL_TESTS OK" -ForegroundColor Green
