# Atualizador automatico de cadeias ICP-Brasil para Windows PowerShell 5.1
# Fonte: Instituto Nacional de Tecnologia da Informacao (ITI)
# Somente adiciona certificados de AC validos do pacote oficial verificado (SHA-512).
# Nao remove certificados, nao altera TLS/SEFAZ e nao modifica certificados A1/A3.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Solicita elevacao via UAC, se necessario.
$identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identidade)
$admin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'Solicitando permissao de Administrador (UAC)...' -ForegroundColor Yellow
    try {
        $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $argumentos = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
        $processo = Start-Process -FilePath $exe -ArgumentList $argumentos -Verb RunAs -Wait -PassThru -ErrorAction Stop
        exit $processo.ExitCode
    } catch {
        Write-Host ('Nao foi possivel obter permissao de administrador: ' + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

$paginaOficial = 'https://www.gov.br/iti/pt-br/assuntos/repositorio/certificados-das-acs-da-icp-brasil-arquivo-unico-compactado'
$zipUrl = 'https://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil/ACcompactado.zip'
$hashUrl = 'https://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil/hashsha512.txt'
$diretorioBase = Join-Path $env:ProgramData 'ICP-Brasil-Atualizador'
$carimbo = Get-Date -Format 'yyyyMMdd-HHmmss'
$diretorioExecucao = Join-Path $diretorioBase ('Execucao-' + $carimbo)
$diretorioExtraido = Join-Path $diretorioExecucao 'extraido'
$zipLocal = Join-Path $diretorioExecucao 'ACcompactado.zip'
$hashLocal = Join-Path $diretorioExecucao 'hashsha512.txt'
$logLocal = Join-Path $diretorioExecucao 'instalacao.log'
$csvLocal = Join-Path $diretorioExecucao 'resultado.csv'
$codigoSaida = 0
$transcricaoIniciada = $false
$detalhes = New-Object 'System.Collections.Generic.List[object]'
$novos = 0
$existentes = 0
$ignorados = 0
$falhas = 0

function Baixar-Oficial {
    param([string]$Url, [string]$Destino)
    $ultimaFalha = ''
    for ($tentativa = 1; $tentativa -le 3; $tentativa++) {
        try {
            Write-Host ('Download (tentativa {0}/3): {1}' -f $tentativa, $Url)
            Invoke-WebRequest -Uri $Url -OutFile $Destino -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $Destino) -or (Get-Item -LiteralPath $Destino).Length -eq 0) {
                throw 'Download vazio.'
            }
            return
        } catch {
            $ultimaFalha = $_.Exception.Message
            Write-Host ('Falha de download: ' + $ultimaFalha) -ForegroundColor Yellow
            if ($tentativa -lt 3) { Start-Sleep -Seconds (3 * $tentativa) }
        }
    }
    throw ('Falha apos 3 tentativas: ' + $ultimaFalha)
}

try {
    New-Item -ItemType Directory -Path $diretorioExecucao, $diretorioExtraido -Force | Out-Null
    Start-Transcript -Path $logLocal -Force | Out-Null
    $transcricaoIniciada = $true

    Write-Host ''
    Write-Host '========================================================' -ForegroundColor Cyan
    Write-Host '  ATUALIZADOR AUTOMATICO - CADEIA ICP-BRASIL' -ForegroundColor Cyan
    Write-Host '========================================================' -ForegroundColor Cyan
    Write-Host ('Fonte: ' + $paginaOficial)
    Write-Host ('Relatorio: ' + $diretorioExecucao)
    Write-Host ''
    Write-Host '[1/5] Preparando conexao segura...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Write-Host '[2/5] Baixando Cadeia Vigente e hash SHA-512 oficial...'
    Baixar-Oficial -Url $hashUrl -Destino $hashLocal
    Baixar-Oficial -Url $zipUrl -Destino $zipLocal

    Write-Host '[3/5] Verificando integridade do ZIP com SHA-512...'
    $conteudoHash = Get-Content -LiteralPath $hashLocal -Raw -ErrorAction Stop
    $encontradosHash = [regex]::Matches($conteudoHash, '(?i)(?<![0-9a-f])[0-9a-f]{128}(?![0-9a-f])')
    if ($encontradosHash.Count -ne 1) {
        throw ('Nao foi encontrado exatamente um hash SHA-512 no arquivo do ITI. Quantidade: ' + $encontradosHash.Count + '. Nada foi instalado.')
    }
    $hashEsperado = $encontradosHash[0].Value.ToUpperInvariant()
    $hashCalculado = (Get-FileHash -LiteralPath $zipLocal -Algorithm SHA512).Hash.ToUpperInvariant()
    if ($hashEsperado -ne $hashCalculado) {
        throw 'HASH SHA-512 DIFERENTE: ZIP invalido ou adulterado. Nada foi instalado.'
    }
    Write-Host 'SHA-512 conferido: OK.' -ForegroundColor Green

    Write-Host '[4/5] Extraindo certificados...'
    Expand-Archive -LiteralPath $zipLocal -DestinationPath $diretorioExtraido -Force -ErrorAction Stop
    $arquivos = @(Get-ChildItem -LiteralPath $diretorioExtraido -Recurse -File | Where-Object { $_.Extension -in @('.crt', '.cer') })
    if ($arquivos.Count -eq 0) { throw 'Nenhum certificado .crt/.cer encontrado no ZIP. Nada foi instalado.' }
    Write-Host ('Certificados encontrados: ' + $arquivos.Count)
    Write-Host '[5/5] Instalando e verificando certificados...'

    foreach ($arquivo in $arquivos) {
        $destino = ''
        $impressao = ''
        try {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($arquivo.FullName)
            $impressao = $cert.Thumbprint
            $agora = Get-Date
            if (($agora -lt $cert.NotBefore) -or ($agora -gt $cert.NotAfter)) {
                $ignorados++
                $motivo = 'Fora do periodo de validade. Confira a data/hora do Windows.'
                Write-Host ('IGNORADO (validade): ' + $arquivo.Name) -ForegroundColor Yellow
                $detalhes.Add([pscustomobject]@{Arquivo=$arquivo.Name;Loja='';Thumbprint=$impressao;Status='IGNORADO';Detalhe=$motivo})
                continue
            }

            # Aceita somente certificados de Autoridade Certificadora (Basic Constraints CA=TRUE).
            $extensaoCA = @($cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' } | Select-Object -First 1)
            $ehAutoridade = $false
            if ($extensaoCA.Count -gt 0) {
                # Em algumas versoes do .NET a extensao vem como X509Extension generica.
                $restricoes = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($extensaoCA[0], $extensaoCA[0].Critical)
                $ehAutoridade = $restricoes.CertificateAuthority
            }
            if (-not $ehAutoridade) {
                $ignorados++
                $motivo = 'Nao possui a extensao CA=TRUE (ou ela nao foi reconhecida).'
                Write-Host ('IGNORADO (nao-AC): ' + $arquivo.Name) -ForegroundColor Yellow
                $detalhes.Add([pscustomobject]@{Arquivo=$arquivo.Name;Loja='';Thumbprint=$impressao;Status='IGNORADO';Detalhe=$motivo})
                continue
            }

            if ($cert.Subject -eq $cert.Issuer) {
                # So adiciona raizes identificadas como ICP-Brasil.
                if ($cert.Subject -notmatch '(?i)Autoridade Certificadora Raiz Brasileira') {
                    $ignorados++
                    $motivo = 'Certificado autoassinado que nao identifica a AC Raiz Brasileira.'
                    Write-Host ('IGNORADO (raiz nao reconhecida): ' + $arquivo.Name) -ForegroundColor Yellow
                    $detalhes.Add([pscustomobject]@{Arquivo=$arquivo.Name;Loja='';Thumbprint=$impressao;Status='IGNORADO';Detalhe=$motivo})
                    continue
                }
                $destino = 'Root'
            } else {
                $destino = 'CA'
            }

            $caminhoStore = 'Cert:\LocalMachine\' + $destino + '\' + $cert.Thumbprint
            if (Test-Path -LiteralPath $caminhoStore) {
                $existentes++
                Write-Host ('JA EXISTIA [{0}]: {1}' -f $destino, $arquivo.Name)
                $detalhes.Add([pscustomobject]@{Arquivo=$arquivo.Name;Loja=$destino;Thumbprint=$impressao;Status='JA EXISTIA';Detalhe='Certificado ja presente na loja correta.'})
                continue
            }

            # certutil usa a loja da maquina quando -user NAO e fornecido.
            $saidaStd = Join-Path $diretorioExecucao 'certutil-out.tmp'
            $saidaErro = Join-Path $diretorioExecucao 'certutil-err.tmp'
            $arg = '-addstore -f ' + $destino + ' "' + $arquivo.FullName + '"'
            $proc = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\certutil.exe') -ArgumentList $arg -Wait -PassThru -NoNewWindow -RedirectStandardOutput $saidaStd -RedirectStandardError $saidaErro -ErrorAction Stop
            $mensagemErro = ''
            if (Test-Path -LiteralPath $saidaErro) {
                $textoErro = Get-Content -LiteralPath $saidaErro -Raw -ErrorAction SilentlyContinue
                if ($null -ne $textoErro) { $mensagemErro = ([string]$textoErro).Trim() }
            }
            if ($proc.ExitCode -ne 0) {
                throw ('certutil retornou codigo ' + $proc.ExitCode + ': ' + $mensagemErro)
            }
            if (-not (Test-Path -LiteralPath $caminhoStore)) {
                throw 'O certutil nao informou erro, mas o certificado nao apareceu na loja esperada.'
            }
            $novos++
            Write-Host ('OK [{0}]: {1}' -f $destino, $arquivo.Name) -ForegroundColor Green
            $detalhes.Add([pscustomobject]@{Arquivo=$arquivo.Name;Loja=$destino;Thumbprint=$impressao;Status='INSTALADO';Detalhe='Confirmado na loja da maquina.'})
        } catch {
            $falhas++
            $msg = $_.Exception.Message
            Write-Host ('FALHA [{0}]: {1} | {2}' -f $destino, $arquivo.Name, $msg) -ForegroundColor Red
            $detalhes.Add([pscustomobject]@{Arquivo=$arquivo.Name;Loja=$destino;Thumbprint=$impressao;Status='FALHA';Detalhe=$msg})
        }
    }

    $detalhes | Export-Csv -LiteralPath $csvLocal -NoTypeInformation -Delimiter ';' -Encoding UTF8
    Write-Host ''
    Write-Host '================= RESULTADO =================' -ForegroundColor Cyan
    Write-Host ('NOVOS INSTALADOS: ' + $novos) -ForegroundColor Green
    Write-Host ('JA EXISTIAM:      ' + $existentes)
    Write-Host ('IGNORADOS:       ' + $ignorados)
    Write-Host ('FALHAS:          ' + $falhas) -ForegroundColor $(if ($falhas -gt 0) { 'Red' } else { 'Green' })
    Write-Host ('Detalhamento: ' + $csvLocal)
    if ($falhas -gt 0) {
        Write-Host 'CONCLUIDO COM FALHAS. Veja o CSV e o log; nao considere a cadeia totalmente instalada.' -ForegroundColor Yellow
        $codigoSaida = 2
    } else {
        Write-Host 'CONCLUIDO: todas as importacoes necessarias tiveram sucesso ou ja existiam.' -ForegroundColor Green
        Write-Host 'Atencao: isso NAO confirma que um certificado A1/A3 nao esteja revogado.' -ForegroundColor Yellow
    }
} catch {
    $codigoSaida = 1
    Write-Host ''
    Write-Host ('INSTALACAO INTERROMPIDA: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Nao prossiga com instalacao de arquivos cuja integridade nao foi confirmada.' -ForegroundColor Yellow
} finally {
    Write-Host ''
    Write-Host ('Relatorios: ' + $diretorioExecucao)
    if ($transcricaoIniciada) { try { Stop-Transcript | Out-Null } catch {} }
    try { [void](Read-Host 'Pressione ENTER para fechar esta janela') } catch {}
    exit $codigoSaida
}
