param(
    [string]$Usuario,
    [string]$SenhaPlain,
    [int]$ChamadoPeloCore = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# ============================================
# CARREGAR SHARED
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
# FUNCOES - INTERFACE
# ============================================

function Selecionar-ModoInstalacao {
    while ($true) {
        Mostrar-TituloNexus "INSTALADOR NEXUS"

        Write-Host "1 - Instalar Terminal"
        Write-Host "2 - Instalar Servidor"
        Write-Host "0 - Voltar"
        Write-Host ""

        $op = (Read-Host "Escolha").Trim()

        switch ($op) {
            "1" { return "TERMINAL" }
            "2" { return "SERVIDOR" }
            "0" { return $null }
            default {
                Mostrar-Erro "Opcao invalida."
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Escolher-SerieInstalador {
    param(
        [array]$Series
    )

    Mostrar-TituloNexus "ESCOLHA DA SERIE"

    Write-Host "Series disponiveis:" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Series.Count; $i++) {
        Write-Host " $($i + 1) - $($Series[$i].Nome)"
    }

    Write-Host ""

    $op = (Read-Host "Escolha a serie").Trim()

    if ($op -notmatch '^\d+$') {
        return $null
    }

    $idx = [int]$op - 1

    if ($idx -lt 0 -or $idx -ge $Series.Count) {
        return $null
    }

    return $Series[$idx]
}

function Escolher-VersaoInstalador {
    param(
        [array]$Versoes,
        [string]$Serie
    )

    Mostrar-TituloNexus "ESCOLHA DA VERSAO"

    Write-Host "Versoes disponiveis em ${Serie}:" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Versoes.Count; $i++) {
        Write-Host " $($i + 1) - $($Versoes[$i].Nome)"
    }

    Write-Host ""

    $op = (Read-Host "Escolha a versao").Trim()

    if ($op -notmatch '^\d+$') {
        return $null
    }

    $idx = [int]$op - 1

    if ($idx -lt 0 -or $idx -ge $Versoes.Count) {
        return $null
    }

    return $Versoes[$idx]
}

# ============================================
# FUNCOES - DIRETORIOS
# ============================================

function Preparar-DiretoriosInstalacao {
    param(
        [string]$MaxPath
    )

    $uteisPath  = Join-Path $MaxPath "_UTEIS"
    $dadosPath  = Join-Path $MaxPath "DADOS"
    $backupPath = Join-Path $MaxPath "BACKUP"
    $tempPath   = Join-Path $env:TEMP "nexus_install"

    foreach ($pasta in @($MaxPath, $uteisPath, $dadosPath, $backupPath, $tempPath)) {
        if (-not (Test-Path $pasta)) {
            New-Item -ItemType Directory -Path $pasta -Force | Out-Null
        }
    }

    return [PSCustomObject]@{
        MaxPath    = $MaxPath
        UteisPath  = $uteisPath
        DadosPath  = $dadosPath
        BackupPath = $backupPath
        TempPath   = $tempPath
    }
}

# ============================================
# FUNCOES - DOWNLOAD
# ============================================

function Baixar-ArquivoPublicoInstalador {
    param(
        [string]$Url,
        [string]$Destino,
        [string]$Nome,
        [int]$MaxTentativas = 3
    )

    for ($tentativa = 1; $tentativa -le $MaxTentativas; $tentativa++) {
        try {
            $sufixo = if ($MaxTentativas -gt 1 -and $tentativa -gt 1) { " (tentativa $tentativa)" } else { "" }
            Write-Host "Baixando: $Nome$sufixo" -NoNewline

            Invoke-WebRequest `
                -Uri $Url `
                -OutFile $Destino `
                -UseBasicParsing `
                -ErrorAction Stop

            Write-Host "  OK" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "  ERRO" -ForegroundColor Red

            if ($tentativa -lt $MaxTentativas) {
                Mostrar-Detalhe "Aguardando para nova tentativa..."
                Start-Sleep -Seconds (2 * $tentativa)
            }
            else {
                Mostrar-Detalhe $_.Exception.Message
            }
        }
    }

    return $false
}

function Baixar-SqlServerIsoRapido {
    param(
        [string]$DestinoBase
    )

    # Usa $script:Cloud em vez de URL hardcoded para consistencia com o restante do modulo
    $path   = "/UTEIS/15 - SQL SERVER/SQL SERVER 2022 TODAS VERSOES"
    $file   = "SQLServer2022-x64-PTB.iso"
    $partes = 8
    $maxTentativasParte = 3

    $destino = Join-Path $DestinoBase "SQL_SERVER_2022"

    if (-not (Test-Path $destino)) {
        New-Item -ItemType Directory -Path $destino -Force | Out-Null
    }

    $url = "$script:Cloud$path/$file"
    $out = Join-Path $destino $file

    if (Test-Path $out) {
        Mostrar-Aviso "Arquivo ISO ja existe. Removendo para novo download..."
        Remove-Item $out -Force -ErrorAction SilentlyContinue
    }

    Get-ChildItem $destino -Filter "$file.part*" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Obtendo tamanho do SQL Server 2022..." -ForegroundColor Cyan

    try {
        $headReq = [System.Net.HttpWebRequest]::Create($url)
        $headReq.Method = "HEAD"
        $headReq.Headers.Add("Authorization", $script:Headers.Authorization)

        $headResp = $headReq.GetResponse()
        $tamanho  = [int64]$headResp.Headers["Content-Length"]
        $headResp.Close()
    }
    catch {
        Mostrar-Erro "Falha ao obter tamanho do ISO."
        Mostrar-Detalhe $_.Exception.Message
        return $false
    }

    if ($tamanho -le 0) {
        Mostrar-Erro "Tamanho do ISO invalido."
        return $false
    }

    Write-Host "Tamanho: $([math]::Round($tamanho / 1GB, 2)) GB" -ForegroundColor Cyan
    Write-Host "Partes: $partes" -ForegroundColor Cyan
    Write-Host ""

    $tamanhoParte = [math]::Floor($tamanho / $partes)

    $jobs      = @()
    $tempParts = @()

    Write-Host "Iniciando download paralelo do SQL Server..." -ForegroundColor Cyan

    for ($i = 0; $i -lt $partes; $i++) {
        $inicio = [int64]($i * $tamanhoParte)
        $fim    = if ($i -eq ($partes - 1)) { [int64]($tamanho - 1) } else { [int64]($inicio + $tamanhoParte - 1) }

        $temp      = "$out.part$i"
        $tempParts += $temp

        $jobs += Start-Job -ScriptBlock {
            param(
                [string]$Url,
                [string]$Authorization,
                [int64]$Inicio,
                [int64]$Fim,
                [string]$Saida,
                [int]$MaxTentativas
            )

            $esperado = ($Fim - $Inicio) + 1

            for ($tentativa = 1; $tentativa -le $MaxTentativas; $tentativa++) {
                # Remove arquivo de tentativa anterior se existir
                if (Test-Path $Saida) {
                    Remove-Item $Saida -Force -ErrorAction SilentlyContinue
                }

                try {
                    $req = [System.Net.HttpWebRequest]::Create($Url)
                    $req.Method = "GET"
                    $req.Headers.Add("Authorization", $Authorization)
                    $req.AddRange($Inicio, $Fim)
                    $req.Timeout = 300000
                    $req.ReadWriteTimeout = 300000

                    $resp = $req.GetResponse()

                    if ([int]$resp.StatusCode -ne 206) {
                        throw "Servidor nao retornou 206 Partial Content. Status: $([int]$resp.StatusCode)"
                    }

                    $inputStream = $resp.GetResponseStream()
                    $fileStream  = [System.IO.File]::Create($Saida)
                    $buffer      = New-Object byte[] 1048576

                    while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                        $fileStream.Write($buffer, 0, $read)
                    }

                    $fileStream.Close()
                    $inputStream.Close()
                    $resp.Close()

                    $baixado = (Get-Item $Saida).Length

                    if ($baixado -ne $esperado) {
                        throw "Parte incompleta. Esperado: $esperado / Baixado: $baixado"
                    }

                    return [PSCustomObject]@{
                        OK       = $true
                        Arquivo  = $Saida
                        Inicio   = $Inicio
                        Fim      = $Fim
                        Bytes    = $baixado
                        Erro     = $null
                        Tentativas = $tentativa
                    }
                }
                catch {
                    $erroMsg = $_.Exception.Message

                    if ($tentativa -lt $MaxTentativas) {
                        Start-Sleep -Seconds (2 * $tentativa)
                        continue
                    }

                    return [PSCustomObject]@{
                        OK       = $false
                        Arquivo  = $Saida
                        Inicio   = $Inicio
                        Fim      = $Fim
                        Bytes    = 0
                        Erro     = $erroMsg
                        Tentativas = $tentativa
                    }
                }
            }
        } -ArgumentList $url, $script:Headers.Authorization, $inicio, $fim, $temp, $maxTentativasParte
    }

    $resultados = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job -Force -ErrorAction SilentlyContinue

    $falhas = @($resultados | Where-Object { $_.OK -ne $true })

    if ($falhas.Count -gt 0) {
        Write-Host ""
        Mostrar-Erro "Erro em uma ou mais partes. Abortando download do SQL Server."

        foreach ($f in $falhas) {
            Mostrar-Aviso "Parte: $($f.Arquivo)"
            Mostrar-Erro  "Erro: $($f.Erro)"
        }

        $tempParts | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
        }

        return $false
    }

    foreach ($p in $tempParts) {
        if (-not (Test-Path $p)) {
            Mostrar-Erro "Parte ausente: $p"
            return $false
        }
    }

    Write-Host ""
    Write-Host "Unindo partes do ISO..." -ForegroundColor Cyan

    try {
        $fs = [System.IO.File]::Open(
            $out,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )

        foreach ($p in $tempParts) {
            $partStream = [System.IO.File]::OpenRead($p)
            $buffer     = New-Object byte[] 1048576

            while (($read = $partStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fs.Write($buffer, 0, $read)
            }

            $partStream.Close()
        }

        $fs.Close()
    }
    catch {
        Mostrar-Erro "Falha ao unir partes do ISO."
        Mostrar-Detalhe $_.Exception.Message
        return $false
    }
    finally {
        $tempParts | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
        }
    }

    $final = (Get-Item $out).Length

    if ($final -eq $tamanho) {
        Write-Host ""
        Mostrar-Sucesso "SQL Server 2022 baixado com sucesso."
        Write-Host "Arquivo: $out" -ForegroundColor Cyan
        return $true
    }

    Mostrar-Erro "Validacao do ISO falhou."
    Mostrar-Detalhe "Esperado: $tamanho / Final: $final"
    return $false
}

# ============================================
# FUNCOES - DEPENDENCIAS
# ============================================

function Test-ProgramaInstalado {
    param(
        [string]$Nome
    )

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $paths) {
        $item = Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$Nome*" } |
            Select-Object -First 1

        if ($item) {
            return $true
        }
    }

    return $false
}

function Instalar-MSI {
    param(
        [string]$Nome,
        [string]$Url,
        [string]$TempPath
    )

    if (Test-ProgramaInstalado $Nome) {
        Write-Host "$Nome ja instalado." -ForegroundColor Yellow
        return
    }

    $msi = Join-Path $TempPath "$Nome.msi"

    if (Baixar-ArquivoPublicoInstalador -Url $Url -Destino $msi -Nome $Nome) {
        Write-Host "Instalando $Nome..." -NoNewline

        try {
            Start-Process msiexec.exe `
                -ArgumentList "/i `"$msi`" /qn /norestart" `
                -Wait

            Write-Host "  OK" -ForegroundColor Green
        }
        catch {
            Write-Host "  ERRO" -ForegroundColor Red
            Mostrar-Detalhe $_.Exception.Message
        }
    }
}

function Instalar-7Zip {
    param(
        [string]$TempPath
    )

    $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"

    if (Test-Path $sevenZipPath) {
        Write-Host "7-Zip ja instalado." -ForegroundColor Yellow
        return $sevenZipPath
    }

    Write-Host "Instalando 7-Zip..." -ForegroundColor Cyan

    $sevenZipExe = Join-Path $TempPath "7zip_installer.exe"

    if (-not (Baixar-ArquivoPublicoInstalador `
        -Url "https://www.7-zip.org/a/7z2409-x64.exe" `
        -Destino $sevenZipExe `
        -Nome "7-Zip")) {
        return $null
    }

    try {
        Start-Process $sevenZipExe "/S" -Wait

        if (Test-Path $sevenZipPath) {
            Mostrar-Sucesso "7-Zip instalado."
            return $sevenZipPath
        }

        Mostrar-Erro "7-Zip nao foi encontrado apos instalacao."
        return $null
    }
    catch {
        Mostrar-Erro "Falha ao instalar 7-Zip."
        Mostrar-Detalhe $_.Exception.Message
        return $null
    }
}

function Liberar-PortasSQL {
    $ports = "1433-1434"

    $regras = @(
        @{ Nome = "SQL-IN-TCP-$ports";  Direcao = "Inbound";  Protocolo = "TCP" },
        @{ Nome = "SQL-OUT-TCP-$ports"; Direcao = "Outbound"; Protocolo = "TCP" },
        @{ Nome = "SQL-IN-UDP-$ports";  Direcao = "Inbound";  Protocolo = "UDP" },
        @{ Nome = "SQL-OUT-UDP-$ports"; Direcao = "Outbound"; Protocolo = "UDP" }
    )

    foreach ($r in $regras) {
        if (Get-NetFirewallRule -DisplayName $r.Nome -ErrorAction SilentlyContinue) {
            Write-Host "Regra ja existe: $($r.Nome)" -ForegroundColor Yellow
        }
        else {
            try {
                New-NetFirewallRule `
                    -DisplayName $r.Nome `
                    -Direction $r.Direcao `
                    -Protocol $r.Protocolo `
                    -LocalPort $ports `
                    -Action Allow | Out-Null

                Write-Host "Regra criada: $($r.Nome)" -ForegroundColor Green
            }
            catch {
                Mostrar-Aviso "Falha ao criar regra: $($r.Nome)"
                Mostrar-Detalhe $_.Exception.Message
            }
        }
    }
}

# ============================================
# FUNCOES - EXTRACAO
# ============================================

function Baixar-PacotesAuxiliares {
    param(
        [string]$TempPath
    )

    $cloudDlls  = "https://cloud.maxdata.com.br/s/5MaMq2RJ5fzYEbA/download/DLLS.rar"
    $cloudUteis = "https://cloud.maxdata.com.br/s/YmCiQWtxNCZZ3jw/download/_Uteis.rar"

    Baixar-ArquivoPublicoInstalador `
        -Url $cloudDlls `
        -Destino (Join-Path $TempPath "dlls.rar") `
        -Nome "DLLs" | Out-Null

    Baixar-ArquivoPublicoInstalador `
        -Url $cloudUteis `
        -Destino (Join-Path $TempPath "uteis.rar") `
        -Nome "Uteis" | Out-Null
}

function Extrair-ArquivosInstalador {
    param(
        [string]$TempPath,
        [string]$MaxPath,
        [string]$UteisPath,
        [string]$SevenZipPath
    )

    Write-Host ""
    Write-Host "Extraindo arquivos..." -ForegroundColor Cyan
    Write-Host ""

    $compactados = @(Get-ChildItem $TempPath -File | Where-Object {
        $_.Extension -in ".rar", ".zip"
    })

    foreach ($arquivo in $compactados) {
        $destExtracao = if ($arquivo.Name -ieq "uteis.rar") { $UteisPath } else { $MaxPath }

        Write-Host "Extraindo $($arquivo.Name)..." -NoNewline

        try {
            & $SevenZipPath x "$($arquivo.FullName)" "-o$destExtracao" -y | Out-Null
            Write-Host "  OK" -ForegroundColor Green
        }
        catch {
            Write-Host "  ERRO" -ForegroundColor Red
            Mostrar-Detalhe $_.Exception.Message
        }
    }
}

# ============================================
# EXECUCAO
# ============================================

$script:Cloud   = "https://cloud.maxdata.com.br/remote.php/webdav"
$script:Base    = "/VERSOES"
$script:Cred    = Nova-CredencialNexus -Usuario $Usuario -SenhaPlain $SenhaPlain
$script:Headers = New-NexusBasicAuthHeader -Usuario $script:Cred.UserName -Credencial $script:Cred

$modo = Selecionar-ModoInstalacao

if (-not $modo) {
    return
}

$maxPath = Selecionar-PastaNexus -Titulo "Selecione a pasta principal da instalacao. Ex: C:\MAX"

if (-not $maxPath) {
    Mostrar-Aviso "Nenhuma pasta selecionada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$dirs = Preparar-DiretoriosInstalacao -MaxPath $maxPath

Mostrar-TituloNexus "BUSCANDO VERSOES"

Write-Host "Buscando series disponiveis..." -ForegroundColor Cyan

$series = @(Get-NexusSeries `
    -Cloud $script:Cloud `
    -Base $script:Base `
    -Credencial $script:Cred)

if ($series.Count -eq 0) {
    Mostrar-Erro "Nenhuma serie encontrada. Verifique as credenciais."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$serieSelecionada = Escolher-SerieInstalador -Series $series

if (-not $serieSelecionada) {
    Mostrar-Erro "Serie invalida."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$versoes = @(Get-NexusVersoes `
    -Cloud $script:Cloud `
    -Path "$script:Base/$($serieSelecionada.Nome)" `
    -Credencial $script:Cred)

if ($versoes.Count -eq 0) {
    Mostrar-Erro "Nenhuma versao encontrada nesta serie."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$versaoSelecionada = Escolher-VersaoInstalador `
    -Versoes $versoes `
    -Serie $serieSelecionada.Nome

if (-not $versaoSelecionada) {
    Mostrar-Erro "Versao invalida."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$baixarSqlIso = $false

if ($modo -eq "SERVIDOR") {
    Mostrar-TituloNexus "INSTALACAO SERVIDOR"

    Write-Host "Instalacao automatica do SQL Server em implementacao." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Sera possivel baixar o ISO do SQL Server 2022 agora." -ForegroundColor Cyan
    Write-Host ""

    $baixarSqlIso = Confirmar-Acao "Deseja baixar o SQL Server 2022?"
}

Mostrar-TituloNexus "CONFIRMACAO"

Write-Host "Modo: $modo" -ForegroundColor Cyan
Write-Host "Pasta principal: $($dirs.MaxPath)" -ForegroundColor Cyan
Write-Host "Serie: $($serieSelecionada.Nome)" -ForegroundColor Cyan
Write-Host "Versao: $($versaoSelecionada.Nome)" -ForegroundColor Cyan
Write-Host "Pasta _UTEIS: $($dirs.UteisPath)" -ForegroundColor Cyan
Write-Host "Pasta DADOS: $($dirs.DadosPath)" -ForegroundColor Cyan
Write-Host "Pasta BACKUP: $($dirs.BackupPath)" -ForegroundColor Cyan

if ($modo -eq "SERVIDOR") {
    Write-Host "Baixar SQL Server 2022: $(if ($baixarSqlIso) { 'SIM' } else { 'NAO' })" -ForegroundColor Yellow
}

Write-Host ""

if (-not (Confirmar-Acao "Confirmar instalacao")) {
    Mostrar-Aviso "Operacao cancelada."
    Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
    return
}

$timer = Iniciar-TimerNexus

$ProgressPreference = 'SilentlyContinue'

try {
    Mostrar-TituloNexus "PREPARANDO INSTALACAO"

    if ($modo -eq "SERVIDOR") {
        Write-Host "Liberando portas SQL..." -ForegroundColor Cyan
        Liberar-PortasSQL
    }

    Write-Host ""
    $sevenZipPath = Instalar-7Zip -TempPath $dirs.TempPath

    if (-not $sevenZipPath) {
        throw "7-Zip indisponivel. Nao sera possivel extrair os arquivos."
    }

    Mostrar-TituloNexus "DOWNLOAD DA VERSAO"

    $resultadoVersao = Invoke-NexusDownloadVersao `
        -Cloud $script:Cloud `
        -Base $script:Base `
        -Serie $serieSelecionada.Nome `
        -Versao $versaoSelecionada.Nome `
        -Destino $dirs.TempPath `
        -Credencial $script:Cred `
        -Headers $script:Headers

    if ($resultadoVersao.OK -eq 0) {
        throw "Nenhum arquivo da versao foi baixado."
    }

    Write-Host ""
    Write-Host "Baixando pastas fiscais..." -ForegroundColor Cyan

    $regexFiscal  = '^(Boleto|CTE|MDFE|NFCE|NFE|NFSE|NFSE2|NFCom).*\.(zip|rar)$'
    $pathVersao   = "$script:Base/$($serieSelecionada.Nome)/$($versaoSelecionada.Nome)"
    $todosDaVersao = @(Get-NexusCloudItems -Cloud $script:Cloud -Path $pathVersao -Credencial $script:Cred)
    $fiscais      = @($todosDaVersao | Where-Object { $_ -match $regexFiscal })

    if ($fiscais.Count -eq 0) {
        Mostrar-Aviso "Nenhuma pasta fiscal encontrada na versao $($versaoSelecionada.Nome)."
    }
    else {
        foreach ($f in $fiscais) {
            $url   = "$script:Cloud$pathVersao/$f"
            $saida = Join-Path $dirs.TempPath $f
            Download-NexusArquivo -Url $url -Destino $saida -Nome $f -Headers $script:Headers | Out-Null
        }
    }

    Write-Host ""
    Write-Host "Baixando pacotes auxiliares..." -ForegroundColor Cyan
    Baixar-PacotesAuxiliares -TempPath $dirs.TempPath

    if ($modo -eq "SERVIDOR" -and $baixarSqlIso) {
        Mostrar-TituloNexus "DOWNLOAD SQL SERVER 2022"
        Baixar-SqlServerIsoRapido -DestinoBase $dirs.UteisPath | Out-Null
    }

    Mostrar-TituloNexus "EXTRACAO"

    Extrair-ArquivosInstalador `
        -TempPath $dirs.TempPath `
        -MaxPath $dirs.MaxPath `
        -UteisPath $dirs.UteisPath `
        -SevenZipPath $sevenZipPath

    Mostrar-TituloNexus "DEPENDENCIAS"

    Instalar-MSI `
        -Nome "SQL Server Native Client" `
        -Url "https://cloud.maxdata.com.br/s/zK2GTCSqXq9C8Kk/download/sqlnclix64.msi" `
        -TempPath $dirs.TempPath

    Instalar-MSI `
        -Nome "ODBC Driver 17 for SQL Server" `
        -Url "https://cloud.maxdata.com.br/s/HbCkKA39Jq4rSRo/download/msodbcsqlx64.msi" `
        -TempPath $dirs.TempPath

    Write-Host ""
    Write-Host "Limpando arquivos temporarios..." -NoNewline

    try {
        if (Test-Path $dirs.TempPath) {
            Remove-Item $dirs.TempPath -Recurse -Force -ErrorAction Stop
        }

        Write-Host "  OK" -ForegroundColor Green
    }
    catch {
        Write-Host "  AVISO" -ForegroundColor Yellow
        Mostrar-Detalhe $_.Exception.Message
    }

    $ProgressPreference = 'Continue'

    Mostrar-TituloNexus "INSTALACAO CONCLUIDA"

    Mostrar-Sucesso "Instalacao concluida."
    Write-Host "Modo: $modo" -ForegroundColor Cyan
    Write-Host "Pasta: $($dirs.MaxPath)" -ForegroundColor Cyan
    Write-Host "Versao: $($versaoSelecionada.Nome)" -ForegroundColor Cyan

    if ($modo -eq "SERVIDOR") {
        Write-Host "SQL Server: instalacao automatica em implementacao." -ForegroundColor Yellow

        if ($baixarSqlIso) {
            Write-Host "ISO SQL Server: $($dirs.UteisPath)\SQL_SERVER_2022\SQLServer2022-x64-PTB.iso" -ForegroundColor Cyan
        }
    }

    Mostrar-TempoExecucao -Inicio $timer -Nome "instalacao"

    Abrir-PastaNexus $dirs.MaxPath
}
catch {
    $ProgressPreference = 'Continue'

    Write-Host ""
    Mostrar-Erro "Falha na instalacao."
    Mostrar-Detalhe $_.Exception.Message
}
finally {
    $ProgressPreference = 'Continue'
}

Pausar-Nexus -ChamadoPeloCore $ChamadoPeloCore
