# NEXUS

NEXUS e um conjunto de scripts PowerShell usado para automacao tecnica da MaxData. Ele roda em clientes/servidores Windows e centraliza tarefas de instalacao, atualizacao, transferencia via cloud/WebDAV e utilitarios de suporte.

O projeto e executado normalmente pelo GitHub Pages:

```powershell
irm https://caio-csar.github.io/NEXUS/NEXUS_CORE.ps1 | iex
```

O `NEXUS_CORE.ps1` pede usuario e senha do cloud, valida as credenciais e baixa os modulos sob demanda a partir do repositorio.

## Menu Atual

Menu principal:

```text
[1] Instalar Sistema
[2] Atualizar Sistema
[3] Baixar Ultima Versao
[4] Baixar Pastas Atualizadas
[5] Transferencia Cloud
[6] Utilitarios
[0] Sair
```

Observacao importante: pressionar `ENTER` vazio no menu principal atualiza/recarrega o NEXUS silenciosamente. Essa opcao nao aparece no menu.

Menu de Utilitarios:

```text
[1] Corrigir WMI
[2] Instalar/Verificar ODBC
[3] Abrir MaxHub
[4] Abrir Pasta do Sistema
[0] Voltar
```

## Arquivos Principais

### `NEXUS_CORE.ps1`

Entrada principal do projeto.

Responsabilidades:

- exigir execucao como administrador;
- pedir credenciais do cloud;
- validar acesso WebDAV;
- baixar `NEXUS_SHARED.ps1` uma vez por sessao;
- baixar e executar modulos;
- exibir menu principal;
- recarregar o core quando o usuario pressiona `ENTER` vazio.

### `NEXUS_SHARED.ps1`

Biblioteca comum usada pelos modulos.

Responsabilidades:

- interface basica de console;
- selecao de arquivos e pastas;
- credenciais e Basic Auth;
- chamadas WebDAV;
- listagem de series e versoes;
- download e upload;
- upload chunked para arquivos grandes;
- painel de transferencia para upload/download;
- controle de tempo de execucao apos confirmacao.

Funcoes importantes:

```text
Nova-CredencialNexus
New-NexusBasicAuthHeader
Get-NexusCloudItems
Get-NexusCloudItemsComTipo
Criar-PastaWebDav
Download-NexusArquivo
Upload-NexusArquivo
Upload-NexusArquivoChunked
Mostrar-PainelTransferenciaNexus
Get-NexusSeries
Get-NexusVersoes
Invoke-NexusDownloadVersao
```

### `modulo_instalador.ps1`

Fluxo de instalacao de Terminal ou Servidor.

Hoje ele:

- permite escolher Terminal ou Servidor;
- escolhe pasta principal, normalmente `C:\MAX`;
- lista series e versoes no cloud;
- baixa versao e pastas fiscais;
- instala/valida ODBC;
- pode baixar ISO do SQL Server 2022 no modo Servidor;
- extrai arquivos usando 7-Zip.

### `modulo_upload.ps1`

Transferencia Cloud.

Usa a pasta WebDAV:

```text
/nexus_upload
```

Permite:

- enviar arquivo;
- compactar pasta em ZIP e enviar;
- listar arquivos enviados;
- baixar arquivos da pasta `nexus_upload`.

Arquivos grandes usam upload em partes pelo endpoint Nextcloud:

```text
/remote.php/dav/uploads/<usuario>/<uploadId>
```

O tamanho padrao de chunk e `10 MB`, e o modo chunked entra a partir de `50 MB`.

### `modulo_utilitarios.ps1`

Utilitarios atuais:

- Corrigir WMI;
- Instalar/Verificar ODBC;
- Abrir MaxHub;
- Abrir Pasta do Sistema.

O MaxHub e baixado do Google Drive como `MaxHub.rar`, extraido em pasta temporaria, executado uma vez e removido quando o processo fecha.

### `modulo_backup.ps1`

Modulo antigo de backup. Hoje nao esta no menu principal, mas contem uma logica util para listar bancos locais via `sqlcmd`.

Essa logica ainda deve ser centralizada no `NEXUS_SHARED.ps1` futuramente.

## Cloud e WebDAV

O NEXUS usa dois formatos principais.

Navegacao geral:

```text
https://cloud.maxdata.com.br/remote.php/webdav
```

Exemplos:

```text
/VERSOES
/VERSOES/<serie>
/VERSOES/<serie>/<versao>
```

Pasta do usuario:

```text
https://cloud.maxdata.com.br/remote.php/dav/files/<usuario>
```

Exemplos:

```text
/nexus_upload
/REGISTRO_SERVIDORES
```

## ODBC

O projeto usa instaladores versionados no repositorio:

```text
installers/odbc/sqlnclix64.msi
installers/odbc/msodbcsqlx64.msi
```

O objetivo e instalar/validar:

```text
SQL Server Native Client
ODBC Driver 17 for SQL Server
```

O menu Utilitarios tambem tem uma opcao para testar/instalar essas dependencias.

## Registro de Servidor

Existe logica dormente em `modulo_utilitarios.ps1` para registrar informacoes do servidor no cloud.

Ela coleta:

- nome do computador;
- usuario Windows;
- IP local;
- pasta MAX;
- banco lido do `max.ini`;
- empresa consultada no banco;
- versao do Manager;
- Windows;
- PowerShell.

Destino planejado:

```text
/REGISTRO_SERVIDORES
```

Essa funcao saiu do menu por enquanto, mas deve ser reaproveitada futuramente para instalacao de terminais.

## MaxHub

No menu Utilitarios, a opcao `Abrir MaxHub`:

1. monta o link confirmado do Google Drive;
2. baixa `MaxHub.rar`;
3. valida assinatura RAR;
4. usa 7-Zip para extrair;
5. localiza o executavel extraido;
6. abre o MaxHub;
7. espera o processo fechar;
8. apaga a pasta temporaria.

## Testes

Os testes ficam em:

```text
tests/
```

Para executar todos:

```powershell
$ErrorActionPreference = 'Stop'
Get-ChildItem -LiteralPath .\tests -Filter *.ps1 | Sort-Object Name | ForEach-Object {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Teste falhou: $($_.Name)" }
}
```

Testes atuais:

```text
NEXUS_CACHE_DOWNLOAD_TESTS.ps1
NEXUS_CORE_MENU_TESTS.ps1
NEXUS_DOWNLOAD_PROGRESS_TESTS.ps1
NEXUS_ODBC_INSTALL_TESTS.ps1
NEXUS_REGISTRO_SERVIDOR_TESTS.ps1
NEXUS_TEMPO_CONFIRMacao_TESTS.ps1
NEXUS_UPLOAD_GRANDE_TESTS.ps1
NEXUS_UTILITARIOS_MENU_TESTS.ps1
NEXUS_WMI_RESET_TESTS.ps1
```

## Publicacao

O usuario executa o NEXUS pelo GitHub Pages, mas os modulos sao baixados do GitHub raw.

Depois de alterar arquivos importantes, publique no repositorio `caio-csar/NEXUS` e force rebuild do Pages quando necessario.

Arquivos que normalmente precisam ser publicados juntos:

```text
NEXUS_CORE.ps1
NEXUS_SHARED.ps1
modulo_*.ps1
Scripts_Uteis/*
tests/*
```

## Cuidados

- Nao remover mudancas locais sem autorizacao.
- Evitar alterar arquivos de backup antigos sem necessidade.
- Manter a opcao de `ENTER` vazio como atualizacao silenciosa.
- Evitar expor senha do cloud em texto puro.
- Nao transformar funcoes dormentes em menu sem confirmar o fluxo com o usuario.
- Para arquivos grandes, manter painel de transferencia enxuto para nao prejudicar desempenho.

## Documentos Relacionados

- `docs/ROADMAP.md`: memoria de decisoes e proximos passos.
- `MAXHUB_CONTEXTO_NEXUS.md`: contexto do NEXUS para uso futuro pelo MaxHub.
