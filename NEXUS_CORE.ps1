[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
Clear-Host

#--------------------------------
# ADMIN
#--------------------------------

if (-not (
 (New-Object Security.Principal.WindowsPrincipal(
   [Security.Principal.WindowsIdentity]::GetCurrent()
 )).IsInRole(
   [Security.Principal.WindowsBuiltInRole]::Administrator
 )
)){
 Write-Host "Execute como Administrador." -ForegroundColor Red
 return
}

#--------------------------------
# CREDENCIAIS
#--------------------------------

$script:Cloud="https://cloud.maxdata.com.br/remote.php/webdav"

$script:Usuario=Read-Host Usuario
$script:Senha=Read-Host Senha -AsSecureString

$script:Cred=New-Object PSCredential(
 $script:Usuario,
 $script:Senha
)

#--------------------------------
# MODULOS
#--------------------------------

$Modulos=@(

 @{Id=1;Nome="Baixar Ultima Versao";Script="modulo_ultima_versao.ps1"}

 @{Id=2;Nome="Atualizacao Gradual";Script="modulo_atualizacao_gradual.ps1"}

 @{Id=3;Nome="Pastas Atualizadas";Script="modulo_pastas_atualizadas.ps1"}

 @{Id=4;Nome="Explorar Uteis";Script="modulo_explorar_uteis.ps1"}

 @{Id=5;Nome="Backup SQL";Script="modulo_backup.ps1"}

 @{Id=6;Nome="Upload WebDAV";Script="modulo_upload.ps1"}

)

#--------------------------------
# BAIXAR MODULO
#--------------------------------

function Baixar-Modulo($nomeArquivo){

$temp=Join-Path $env:TEMP $nomeArquivo

$url="$script:Cloud/NEXUS/$nomeArquivo"

$senhaPlain=$script:Cred.GetNetworkCredential().Password

$credBasic=[Convert]::ToBase64String(
[Text.Encoding]::ASCII.GetBytes(
"$($script:Usuario):$senhaPlain"
))

$headers=@{
Authorization="Basic $credBasic"
}

try{

Invoke-WebRequest `
-Uri $url `
-OutFile $temp `
-Headers $headers `
-UseBasicParsing `
-ErrorAction Stop

if(Test-Path $temp){
return $temp
}

}
catch{

Write-Host "Falha ao baixar modulo." -ForegroundColor Red
Write-Host $_.Exception.Message

}

return $null

}

#--------------------------------
# EXECUTAR MODULO
#--------------------------------

function Executar-Modulo($mod){

Clear-Host

Write-Host "Carregando $($mod.Nome)..." -ForegroundColor Cyan

$arquivo=Baixar-Modulo $mod.Script

if(-not $arquivo){
 Read-Host "ENTER"
 return
}

try{

powershell.exe `
-NoProfile `
-ExecutionPolicy Bypass `
-File $arquivo `
-Usuario $script:Usuario `
-SenhaPlain ($script:Cred.GetNetworkCredential().Password) `
-ChamadoPeloCore 1
}
catch{

Write-Host "Erro executando modulo." -ForegroundColor Red
Write-Host $_.Exception.Message

}

Remove-Item $arquivo -Force -ErrorAction SilentlyContinue

Read-Host "`nENTER para voltar"

}

#--------------------------------
# MENU
#--------------------------------

while($true){

Clear-Host

Write-Host ""
Write-Host "========= MAXDATA NEXUS =========" -ForegroundColor Cyan
Write-Host ""

foreach($m in $Modulos){
Write-Host " $($m.Id) - $($m.Nome)"
}

Write-Host ""
Write-Host " X - Sair" -ForegroundColor Red
Write-Host ""

$op=(Read-Host Escolha).Trim()

if($op.ToUpper() -eq "X"){break}

if($op -notmatch '^\d+$'){continue}

$sel=$Modulos | Where-Object {
$_.Id -eq [int]$op
}

if($sel){
Executar-Modulo $sel
}

}

Write-Host Encerrado.