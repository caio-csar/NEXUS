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

function Get-CloudItemsComTipo($path){

$url="$cloud$path"

$body='<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/><d:resourcetype/></d:prop></d:propfind>'

$r=[System.Net.HttpWebRequest]::Create($url)

$r.Method="PROPFIND"
$r.Headers.Add("Depth","1")
$r.Credentials=$cred

$s=$r.GetRequestStream()
$w=New-Object IO.StreamWriter($s)
$w.Write($body)
$w.Close()

$resp=$r.GetResponse()

$reader=New-Object IO.StreamReader(
$resp.GetResponseStream()
)

$xml=[xml]$reader.ReadToEnd()

$reader.Close()
$resp.Close()

$it=@()

$xml.multistatus.response |
Select-Object -Skip 1 |
ForEach-Object{

$nome=$_.propstat.prop.displayname

$pasta=$_.propstat.prop.resourcetype.collection -ne $null

if($nome){

$it += [PSCustomObject]@{
Nome=$nome
Tipo=if($pasta){"PASTA"}else{"ARQUIVO"}
}

}

}

return $it
}

$path="/UTEIS"

while($true){

Clear-Host

Write-Host "Caminho: $path"

$items=Get-CloudItemsComTipo $path

Write-Host "0-Voltar"

for($i=0;$i -lt $items.Count;$i++){
Write-Host "$($i+1)-$($items[$i].Nome)"
}

$op=(Read-Host Escolha).Trim()

if($op -eq "0"){break}

if($op -match '^\d+$'){

$idx=[int]$op-1

if($idx -ge 0 -and $idx -lt $items.Count){

$item=$items[$idx]

if($item.Tipo -eq "PASTA"){
$path="$path/$($item.Nome)"
}
else{

Invoke-WebRequest `
-Uri "$cloud$path/$($item.Nome)" `
-OutFile "$destBase\$($item.Nome)" `
-Headers $authHeaders `
-UseBasicParsing

}

}

}

}