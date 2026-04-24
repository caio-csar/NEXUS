param(
[string]$Usuario,
[string]$SenhaPlain,
[int]$ChamadoPeloCore=0
)

if($ChamadoPeloCore){
$Senha=ConvertTo-SecureString $SenhaPlain -AsPlainText -Force
}
else{
if(-not $Usuario){$Usuario=Read-Host Usuario}
$Senha=Read-Host Senha -AsSecureString
}

$cloud="https://cloud.maxdata.com.br/remote.php/webdav"
$cred=New-Object PSCredential($Usuario,$Senha)

$senhaLocal=$cred.GetNetworkCredential().Password

$credBasic=[Convert]::ToBase64String(
[Text.Encoding]::ASCII.GetBytes("${Usuario}:${senhaLocal}")
)

$authHeaders=@{
Authorization="Basic $credBasic"
}

$destBase="$env:USERPROFILE\Downloads\nexus"

if(!(Test-Path $destBase)){
New-Item -ItemType Directory -Path $destBase | Out-Null
}

function Get-CloudItems($path){

$url="$cloud$path"

$body='<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>'

$r=[System.Net.HttpWebRequest]::Create($url)
$r.Method="PROPFIND"
$r.Headers.Add("Depth","1")
$r.Credentials=$cred

$s=$r.GetRequestStream()
$w=New-Object IO.StreamWriter($s)
$w.Write($body)
$w.Close()

$resp=$r.GetResponse()
$reader=New-Object IO.StreamReader($resp.GetResponseStream())
$xml=[xml]$reader.ReadToEnd()

$reader.Close()
$resp.Close()

$it=@()

$xml.multistatus.response |
Select-Object -Skip 1 |
ForEach-Object{
$n=$_.propstat.prop.displayname
if($n){$it+=$n}
}

return $it
}

$base="/VERSOES"

$series=(Get-CloudItems $base)|Where-Object{
$_ -match '^v\d+'
}

foreach($serie in $series){

Write-Host "Serie $serie"

$versoes=(Get-CloudItems "$base/$serie") |
Where-Object{
$_ -match '^\d+\.'
}

for($i=0;$i -lt $versoes.Count;$i++){
Write-Host "$($i+1)-$($versoes[$i])"
}

$entrada=(Read-Host Escolha).Trim()

if(!$entrada){continue}

$entrada.Split(",") | ForEach-Object {

$idx=[int]$_.Trim()-1

if($idx -ge 0 -and $idx -lt $versoes.Count){

$v=$versoes[$idx]

$arquivos=Get-CloudItems "$base/$serie/$v"

foreach($f in $arquivos){

if($f -match "Max_Manager" -and $f -match '\.(zip|rar)$'){

Invoke-WebRequest `
-Uri "$cloud$base/$serie/$v/$f" `
-OutFile "$destBase\$f" `
-Headers $authHeaders `
-UseBasicParsing

break

}

}

}

}

}