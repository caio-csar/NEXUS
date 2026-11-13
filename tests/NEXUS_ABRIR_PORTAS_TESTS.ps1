$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$utilPath = Join-Path $repo "modulo_utilitarios.ps1"
$installerPath = Join-Path $repo "modulo_instalador.ps1"

$tokens = $null
$erros = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($utilPath, [ref]$tokens, [ref]$erros)
if ($erros.Count -gt 0) { throw "Sintaxe invalida em Utilitarios: $($erros | Out-String)" }

$matches = @($ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $n.Name -eq 'Abrir-PortasSqlNexus'
}, $true))
if ($matches.Count -ne 1) { throw "A funcao Abrir-PortasSqlNexus deve existir uma unica vez." }

$codigo = $matches[0].Extent.Text
$instalador = Get-Content -LiteralPath $installerPath -Raw
foreach ($regra in @('SQL-IN-TCP-', 'SQL-OUT-TCP-', 'SQL-IN-UDP-', 'SQL-OUT-UDP-')) {
    if (-not $codigo.Contains($regra) -or -not $instalador.Contains($regra)) {
        throw "Regra divergente do instalador: $regra"
    }
}
if (-not $codigo.Contains('Confirmar-Acao')) {
    throw "A abertura de portas deve exigir confirmacao."
}

. ([scriptblock]::Create($codigo))

$script:confirmado = $false
$script:regrasFirewall = @{}
$script:criadas = 0
$script:errosFirewall = New-Object 'System.Collections.Generic.List[string]'
$script:sucessos = New-Object 'System.Collections.Generic.List[string]'
function Mostrar-TituloNexus { param([string]$Titulo) }
function Confirmar-Acao { param([string]$Mensagem) return $script:confirmado }
function Mostrar-Aviso { param([string]$Mensagem) }
function Mostrar-Erro { param([string]$Mensagem) $script:errosFirewall.Add($Mensagem) }
function Mostrar-Sucesso { param([string]$Mensagem) $script:sucessos.Add($Mensagem) }

# Os mocks impedem qualquer modificacao no Firewall real (inclusive no runner Windows).
function Get-NetFirewallRule {
    param([string]$DisplayName, [string]$ErrorAction)
    if ($script:regrasFirewall.ContainsKey($DisplayName)) {
        return $script:regrasFirewall[$DisplayName]
    }
}
function New-NetFirewallRule {
    param(
        [string]$DisplayName, [string]$Direction, [string]$Protocol,
        [string]$LocalPort, [string]$Action, [string]$ErrorAction
    )
    if ($LocalPort -ne '1433-1434' -or $Action -ne 'Allow') {
        throw "Portas ou acao invalidas."
    }
    if ($script:regrasFirewall.ContainsKey($DisplayName)) {
        throw "Regra duplicada."
    }
    $script:regrasFirewall[$DisplayName] = [pscustomobject]@{
        DisplayName = $DisplayName
        Enabled = 'True'
        Action = $Action
        Direction = $Direction
        Protocol = $Protocol
        LocalPort = $LocalPort
    }
    $script:criadas++
}

Abrir-PortasSqlNexus
if ($script:criadas -ne 0) { throw "Cancelamento nao respeitado." }

$script:confirmado = $true
Abrir-PortasSqlNexus
if ($script:criadas -ne 4 -or $script:regrasFirewall.Count -ne 4) {
    throw "Primeira execucao nao criou as quatro regras."
}

Abrir-PortasSqlNexus
if ($script:criadas -ne 4 -or -not ($script:sucessos -match 'ja existiam')) {
    throw "Segunda execucao deveria reutilizar regras existentes sem duplicacao."
}

$script:regrasFirewall['SQL-IN-TCP-1433-1434'].Enabled = 'False'
Abrir-PortasSqlNexus
if ($script:criadas -ne 4 -or $script:errosFirewall.Count -eq 0) {
    throw "Regra preexistente desativada nao pode ser relatada como sucesso."
}

Write-Host "NEXUS_ABRIR_PORTAS_TESTS OK" -ForegroundColor Green
