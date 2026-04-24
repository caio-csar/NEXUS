param(
[string]$Usuario,
[string]$SenhaPlain,
[int]$ChamadoPeloCore=0
)

#--------------------------------
# CREDENCIAIS
#--------------------------------

if($ChamadoPeloCore -eq 1){

$Senha = ConvertTo-SecureString `
$SenhaPlain `
-AsPlainText `
-Force

}
else{

if(-not $Usuario){
$Usuario=Read-Host "Usuario"
}

$Senha=Read-Host "Senha" -AsSecureString

}

$cred = New-Object PSCredential(
$Usuario,
$Senha
)

#--------------------------------
# PASTA LOCAL
#--------------------------------

$basePath="C:\BackupSQL"

if(!(Test-Path $basePath)){
New-Item `
-Path $basePath `
-ItemType Directory | Out-Null
}

#--------------------------------
# LISTAR BANCOS
#--------------------------------

$dbs=sqlcmd `
-Q "set nocount on;select name from sys.databases where database_id>4" `
-h -1 -W |
Where-Object{
$_ -ne ""
}

if(!$dbs){
Write-Host "Nenhum banco encontrado." -ForegroundColor Red
exit
}

$i=1

foreach($item in $dbs){

Write-Host "$i - $item"

$i++

}

$escolha=(Read-Host "Selecione o banco").Trim()

if($escolha -notmatch '^\d+$'){
Write-Host "Opcao invalida." -ForegroundColor Red
exit
}

$db=$dbs[[int]$escolha-1].Trim()

#--------------------------------
# BACKUP
#--------------------------------

$stamp=Get-Date -Format yyyyMMdd_HHmm

$bak=Join-Path `
$basePath `
"$db`_$stamp.bak"

$zip=$bak -replace '\.bak$','.zip'

Write-Host "Gerando backup..." -ForegroundColor Cyan

sqlcmd `
-Q "BACKUP DATABASE [$db] TO DISK=N'$bak' WITH INIT"

if(!(Test-Path $bak)){
Write-Host "Erro no backup." -ForegroundColor Red
exit
}

Write-Host "Compactando..." -ForegroundColor Cyan

Compress-Archive `
-Path $bak `
-DestinationPath $zip `
-Force

Remove-Item $bak -Force

#--------------------------------
# WEBDAV
#--------------------------------

$cloudRoot="https://cloud.maxdata.com.br/remote.php/dav/files/$Usuario"

$folderUrl="$cloudRoot/nexus_backup"

$fileName=Split-Path $zip -Leaf

$fullUrl="$folderUrl/$fileName"

#--------------------------------
# CRIAR PASTA
#--------------------------------

try{

$req=[System.Net.HttpWebRequest]::Create(
$folderUrl
)

$req.Method="MKCOL"

$req.Credentials=$cred

$req.GetResponse().Close()

}
catch{
# ignora conflito 409
}

#--------------------------------
# UPLOAD
#--------------------------------

try{

Write-Host "Enviando backup..." -ForegroundColor Cyan

$reqPut=[System.Net.HttpWebRequest]::Create(
$fullUrl
)

$reqPut.Method="PUT"

$reqPut.Credentials=$cred

$bytes=[System.IO.File]::ReadAllBytes(
$zip
)

$reqPut.ContentLength=$bytes.Length

$stream=$reqPut.GetRequestStream()

$stream.Write(
$bytes,
0,
$bytes.Length
)

$stream.Close()

$reqPut.GetResponse().Close()

Write-Host "Backup enviado com sucesso." `
-ForegroundColor Green

}
catch{

Write-Host "Falha no upload:" `
-ForegroundColor Red

Write-Host $_.Exception.Message

}
finally{

if(Test-Path $zip){
Remove-Item $zip -Force
}

}