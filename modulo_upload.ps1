param(
    [string]$Usuario,
    [string]$SenhaPlain,
    [int]$ChamadoPeloCore = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Add-Type -AssemblyName System.Windows.Forms

Write-Host "=== Upload de Pasta para WebDAV ===" -ForegroundColor Cyan
Write-Host ""

# ID INTERNO DO WEBDAV
$webdavUser = "caio.cesar"
$cloudRoot = "https://cloud.maxdata.com.br/remote.php/dav/files/$webdavUser"

$Secure = ConvertTo-SecureString $SenhaPlain -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential($Usuario, $Secure)

# Selecionar pasta
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = "Selecione a pasta para enviar ao WebDAV"

if ($dialog.ShowDialog() -ne "OK") {
    Write-Host "Nenhuma pasta selecionada." -ForegroundColor Yellow
    return
}

$pastaOrigem = $dialog.SelectedPath
$nomePasta = Split-Path $pastaOrigem -Leaf

$data = Get-Date -Format "yyyyMMdd_HHmmss"
$zip = Join-Path $env:TEMP "$nomePasta`_$data.zip"

Write-Host "Pasta selecionada: $pastaOrigem"
Write-Host "Compactando pasta..."

try {
    Compress-Archive `
        -Path "$pastaOrigem\*" `
        -DestinationPath $zip `
        -Force `
        -ErrorAction Stop
}
catch {
    Write-Host "Erro ao compactar pasta." -ForegroundColor Red
    Write-Host $_.Exception.Message
    return
}

if (!(Test-Path $zip)) {
    Write-Host "Erro ao criar arquivo ZIP." -ForegroundColor Red
    return
}

$pastaWebDav = "$cloudRoot/nexus_upload"

Write-Host "Verificando pasta no WebDAV..."

try {
    $r = [System.Net.HttpWebRequest]::Create($pastaWebDav)
    $r.Method = "MKCOL"
    $r.Credentials = $Cred

    try {
        $r.GetResponse().Close()
    }
    catch {
        # 409 = pasta ja existe
    }
}
catch {}

$nomeZip = Split-Path $zip -Leaf
$url = "$pastaWebDav/$nomeZip"

Write-Host "Enviando ZIP..."
Write-Host $url

try {
    Invoke-WebRequest `
        -Uri $url `
        -Method Put `
        -InFile $zip `
        -Credential $Cred `
        -UseBasicParsing `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "Upload OK" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Erro no upload." -ForegroundColor Red
    Write-Host $_.Exception.Message
}
finally {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
}

if ($ChamadoPeloCore -ne 1) {
    Read-Host "`nPressione ENTER para sair"
}