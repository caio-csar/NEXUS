# ROADMAP NEXUS

Este arquivo guarda o estado mental do projeto para que ele possa ser continuado em outro computador ou por outro Codex.

## Estado Atual

O NEXUS ja possui:

- core com login no cloud e validacao WebDAV;
- menu principal sobrio;
- atualizacao silenciosa ao pressionar `ENTER` vazio no menu principal;
- cache do `NEXUS_SHARED.ps1` por sessao;
- downloads com anti-cache para evitar modulo antigo;
- painel de transferencia para upload e download;
- upload chunked para arquivos grandes;
- instalacao/verificacao de ODBC;
- WMI reset via utilitario;
- abertura temporaria do MaxHub;
- testes automatizados em `tests/`.

## Decisoes Ja Tomadas

### Menu

Menu principal atual:

```text
[1] Instalar Sistema
[2] Atualizar Sistema
[3] Baixar Ultima Versao
[4] Baixar Pastas Atualizadas
[5] Transferencia Cloud
[6] Utilitarios
[0] Sair
```

O item "Backup para Cloud" foi removido do menu.

`Enviar arquivos para o Cloud` virou:

```text
Transferencia Cloud
```

### Utilitarios

Menu atual:

```text
[1] Corrigir WMI
[2] Instalar/Verificar ODBC
[3] Abrir MaxHub
[4] Abrir Pasta do Sistema
[0] Voltar
```

Foram removidos do menu:

- Limpar Temporarios;
- Diagnostico do Ambiente;
- Gerar Log;
- Explorar Arquivos Uteis;
- Registrar Servidor no Cloud.

O registro de servidor continua no codigo, mas dormente.

### Progresso de Transferencias

Upload e download usam painel reaproveitado no console.

Formato conceitual:

```text
Operacao: Upload
Arquivo : arquivo.sql
Parte   : 31 / 285
Enviado :  325058560 bytes
Total   : 2979168596 bytes
Falta   : 2654110036 bytes
Progresso: 10,91%
```

Para fluxos continuos, evitar atualizar o console em excesso. A regra usada hoje e atualizar em intervalos, para nao deixar a transferencia lenta.

### MaxHub

O MaxHub fica no Google Drive publico do usuario.

O NEXUS:

- baixa o RAR;
- extrai em pasta temporaria;
- abre o executavel;
- espera fechar;
- remove a pasta temporaria.

Se futuramente o Drive ficar instavel, alternativa recomendada:

```text
/UTILITARIOS/MAXHUB/MaxHub.rar
```

no WebDAV MaxData.

### ODBC

Os instaladores foram adicionados ao repositorio:

```text
installers/odbc/sqlnclix64.msi
installers/odbc/msodbcsqlx64.msi
```

A logica atual valida registro do Native Client e ODBC 17.

### WMI

`Scripts_Uteis/wmi_reset.bat` foi publicado no repositorio.

Quando nao consegue remover/renomear o Repository por bloqueio do Windows, a correcao agenda uma tarefa para rodar no proximo boot.

## Ideias Dormentes

### Registro Automatico de Servidor

Objetivo:

```text
Ao fazer login no NEXUS no servidor, registrar automaticamente informacoes tecnicas em /REGISTRO_SERVIDORES.
```

Dados planejados:

- computador;
- IP local;
- usuario Windows;
- pasta MAX;
- banco do `max.ini`;
- empresa;
- versao do Manager;
- Windows;
- PowerShell;
- data/hora.

Uso futuro:

```text
Instalacao de terminal lista servidores registrados e usa os dados para configurar o terminal.
```

### Terminal e `max.ini`

Foi observado que o `max.ini` gerado pelo `max_atualiza` nasce com algo parecido com:

```ini
[CON]
User Id=...
Passwd=...
Initial catalog=MAX
Data Source=NOME-LOCAL
iplocal=s
```

Decisao planejada:

- nao mexer em `User Id`;
- nao mexer em `Passwd`;
- nao mexer em `iplocal`;
- alterar apenas `Initial catalog`;
- alterar apenas `Data Source`.

Para terminal, preferir `Data Source` com nome do computador servidor, nao IP, porque nem todo cliente tem IP fixo.

### Deteccao de Bancos SQL

Hoje existe logica em `modulo_backup.ps1`:

```sql
select name
from sys.databases
where database_id > 4
order by name
```

Ela deve ser centralizada futuramente em `NEXUS_SHARED.ps1`, com uma funcao como:

```powershell
Get-BancosSqlLocalNexus
```

Melhorias desejadas:

- tentar `localhost`;
- tentar `.`;
- tentar `.\SQLEXPRESS`;
- tentar nome do computador;
- detectar instancias SQL no registro;
- lidar com ausencia de `sqlcmd`;
- retornar objetos estruturados com instancia e banco.

### Verificacao de Espaco em Disco

Ponto ideal:

- antes da confirmacao final da instalacao;
- antes de downloads grandes;
- antes de extracao;
- antes de baixar MaxHub;
- antes de download da Transferencia Cloud.

Regra inicial sugerida:

```text
espaco necessario = tamanho estimado do download x 2,5
```

Para servidor com ISO SQL, usar folga maior.

### Mini Interface

Foi debatido que o melhor caminho e hibrido:

```text
PowerShell continua como motor
Mini UI futura chama o motor
```

PowerShell deve continuar responsavel por:

- admin;
- download;
- WebDAV;
- MSI/BAT;
- arquivos em `C:\MAX`;
- `max.ini`;
- ODBC;
- WMI.

Uma interface futura seria boa para:

- login;
- menu;
- escolha de versao;
- escolha de servidor registrado;
- progresso;
- logs.

## Proximas Implementacoes Recomendadas

1. Centralizar listagem de bancos SQL no `NEXUS_SHARED.ps1`.
2. Implementar verificacao de espaco em disco.
3. Ativar registro automatico de servidor apos login, em modo silencioso.
4. Na instalacao de terminal, listar servidores registrados.
5. Ajustar `max.ini` do terminal com banco e servidor escolhido.
6. Avaliar hospedagem do MaxHub no WebDAV em vez de Google Drive.
7. Limpar arquivos antigos de backup do repositorio quando for seguro.

## Como Continuar em Outro Computador

1. Clonar ou baixar o repositorio `caio-csar/NEXUS`.
2. Abrir a pasta no Codex.
3. Ler `README.md`.
4. Ler este `docs/ROADMAP.md`.
5. Ler `MAXHUB_CONTEXTO_NEXUS.md` se a tarefa envolver MaxHub.
6. Rodar os testes antes de mexer:

```powershell
$ErrorActionPreference = 'Stop'
Get-ChildItem -LiteralPath .\tests -Filter *.ps1 | Sort-Object Name | ForEach-Object {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Teste falhou: $($_.Name)" }
}
```

7. Depois de alterar, publicar no GitHub e confirmar raw/GitHub Pages quando necessario.

## Observacoes Para o Proximo Codex

- O usuario prefere respostas praticas e diretas.
- O usuario chama o assistente de "mestre".
- Nao desfazer mudancas locais sem autorizacao.
- Quando o usuario pergunta "daria para", normalmente ele quer debater antes de implementar.
- Quando ele diz "implemente agora", publicar no GitHub costuma ser esperado.
- Usar testes antes de alterar comportamento.
- Usar `rg` para buscar arquivos/textos.
- Usar `apply_patch` para edicoes manuais.
- Evitar menus com visual exagerado; o usuario preferiu cabecalho sobrio.
