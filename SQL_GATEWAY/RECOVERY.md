# Nexus SQL Gateway — recuperação do baseline

Versão do pacote: **0.8.0-HOTFIX2**. Versão interna do assembly: 0.8.0.

## Estado deste registro

O código-fonte original foi recuperado e validado em 19/11/2026. Esta revisão contém o registro do baseline; a importação dos arquivos de código-fonte ainda está pendente. Não confundir este commit com uma release completa.

- Pacote original: `Nexus_SQL_Gateway_0.8.0_HOTFIX2_SOURCE.zip`
- SHA-256: `c043d52e82248c52bc5d185368558684b93595a07f565f04076851f14dcaeebb`
- 50 arquivos no pacote; 49 checksums internos coincidentes.
- Distribuição recebida: `NexusSqlGateway-win-x64.zip`
- SHA-256: `f4bf379ae065106cd60fa5dae048d29dc91e3256c3c79841bdb44f28b6933054`
- README, CHANGELOG e VERSION coincidem entre os dois pacotes.
- SHA-256 e integridade do ZIP não comprovam que o executável corresponde bit a bit a uma compilação dos fontes; o build não foi repetido nesta recuperação.

## Organização

- Branch dedicada: `sql-gateway` (não modifica `main`).
- Código-fonte, projetos, testes e scripts em `SQL_GATEWAY/`.
- Tag proposta após a importação completa: `sql-gateway-v0.8.0-hotfix2`.
- Binários gerados e configurações locais ficam fora do Git; releases binárias devem ser anexadas a releases apropriadas, não ao histórico de código.
