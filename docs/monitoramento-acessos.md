# Monitoramento de aberturas do NEXUS

## Objetivo
Registrar apenas cada abertura do NEXUS apos a etapa de autenticacao,
associando usuario do Cloud, computador, usuario Windows, versao do Windows e horario.

O monitoramento **nao** registra senhas, IP, MAC, comandos executados,
conteudo de clientes ou modulos utilizados. Nao ha nova opcao no menu.

O registro e complementar: erro de rede, configuracao invalida ou falha do
servidor nao deve impedir o funcionamento normal do NEXUS.

## Arquitetura
1. O `NEXUS_CORE.ps1` consulta `monitoramento/config.json` no GitHub publico.
2. Se `enabled` for `false` (padrao), nao envia nenhum evento.
3. Quando habilitado, o CORE envia somente o JSON minimo por HTTPS
   para `/nexus/access` de um Cloudflare Worker.
4. O Worker verifica a configuracao e confirma que o repositorio de destino
   no GitHub e **privado** antes de escrever um novo JSON.
5. O token do GitHub fica exclusivamente nos Secrets do Worker.

Cada acesso gera um arquivo:
`acessos/AAAA-MM-DD/<timestamp>-<uuid>.json`

Exemplo:
```json
{
  "evento": "abertura_nexus",
  "data_hora_servidor": "2026-11-05T18:48:22.000Z",
  "data_hora_cliente": "2026-11-05T15:48:22-03:00",
  "usuario_nexus": "tecnico01",
  "computador": "PC-SUPORTE",
  "usuario_windows": "Suporte",
  "sistema_operacional": "Microsoft Windows NT 10.0.22631.0"
}
```

## Ativacao (nao automatica)

1. No GitHub, crie o repositorio `caio-csar/NEXUS-Logs` como **Private**,
   inicializando-o com README para haver uma branch `main`.
   O conector de GitHub utilizado para este trabalho nao possui acao de criacao
   de repositorio, portanto essa etapa deve ser feita pelo proprietario.
2. Crie um **fine-grained personal access token** com acesso **apenas**
   a `NEXUS-Logs` e permissao de Contents: Read and write.
   Nunca inclua esse token em arquivos do NEXUS ou no codigo-fonte do Worker.
3. Crie e publique um Cloudflare Worker usando
   `cloudflare/nexus-access-worker.mjs`.
4. Nas configuracoes do Worker, defina as variaveis/Secrets:
   - `GITHUB_TOKEN` (Secret): token do passo 2.
   - `GITHUB_REPO` (variavel): `caio-csar/NEXUS-Logs`.
   - `GITHUB_BRANCH` (opcional): `main`.
5. Configure no Cloudflare regras de limite de requisicoes para evitar abuso,
   pois o cliente publico nao possui uma credencial forte de identificacao.
6. Antes de habilitar os clientes, teste o endpoint com um JSON de exemplo
   e confira se surgiu um arquivo **no repositorio privado**. A resposta
   esperada apos gravacao e HTTP 204.
7. Atualize `monitoramento/config.json` na branch `main` para:
   ```json
   {
     "enabled": true,
     "endpoint": "https://SEU-WORKER.workers.dev/nexus/access"
   }
   ```
8. Teste uma abertura do NEXUS em um Windows controlado, conferindo
   o registro. Em seguida valide os fluxos de menus e modulos existentes.

## Desativacao / rollback
Para parar os envios sem mudar o CORE:
`enabled: false` em `monitoramento/config.json` na `main`.
Uma falha de consulta ao arquivo de configuracao tambem impede o envio,
sem bloquear a aplicacao.

O modulo nao depende do Worker para iniciar. Pode-se ainda restaurar a
versao anterior do CORE em caso de regressao.

## Consideracoes de seguranca e privacidade
- O repositorio `NEXUS` e publico. **O monitoramento nao e secreto no codigo.**
  Nao deve ser usado como mecanismo de vigilancia clandestina. Informe o
  tratamento de dados por politica interna/aviso aplicavel antes de ativa-lo.
  Isso nao exige mensagens em cada abertura.
- O endpoint e publico; dados declarados pelo cliente **podem ser falsificados**.
  Os registros servem para acompanhamento operacional, nao como prova de identidade.
- Use regras antiabuso no Cloudflare e limite os tokens do Worker ao repo de logs.
- O GitHub preserva o historico de commits: apagar um arquivo nao garante
  que os dados sejam eliminados do historico. Defina retencao e controles de acesso.
- A data do servidor e a referencia mais confiavel; o relogio do cliente
  pode estar incorreto.
- Falhas de rede podem causar lacunas. O script nao bloqueia o usuario
  e nao guarda fila local contendo identificadores do computador.

## Testes
No Node.js 22:
```bash
node --test tests/NEXUS_ACCESS_WORKER_TESTS.mjs
```

No PowerShell 7:
```powershell
pwsh -NoProfile -File tests/NEXUS_CORE_MENU_TESTS.ps1
pwsh -NoProfile -File tests/NEXUS_MONITORAMENTO_TESTS.ps1
```
