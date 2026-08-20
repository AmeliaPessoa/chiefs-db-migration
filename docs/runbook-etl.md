# Runbook · ETL intelligence → destino (P2)

Entregável do critério "a Chiefs opera sozinha" (briefing §2). Cobre: como
rodar, quando, com qual credencial, o que monitorar, como reprocessar e o
que quebra se ninguém cuidar. Validado em homolog em 19/08/2026 (348 mil+
linhas, zero divergências, origem viva).

## O que o ETL faz

1. **Carga full** (espelho 1:1) das **48 tabelas** que nascem no
   Intelligence → schema `intelligence` do Postgres principal
   (TRUNCATE + INSERT, transação única, `setval` das 42 sequences);
2. **Merge das híbridas** no main (`--merge`): `app.chiefs` +53 colunas
   (fonte `chiefs_ativos` ∪ `chiefs_todos`, ativos vence conflito) e
   `app.pipedrive_deals` +4 colunas (`notes`, `files`,
   `origem_oportunidade`, `utm_source`), casando
   `pipedrive_id = intel.id`. Só escreve colunas novas; ids sem match são
   descartados e contabilizados;
3. **Validação**: contagens 48/48 origem × destino (um único snapshot
   REPEATABLE READ — vale mesmo com gravadores ativos na origem) +
   fidelidade do merge por ROW compare.

## Como rodar (caminho padrão: `etl.py`)

```bash
pip3 install psycopg2-binary   # uma vez por máquina

SRC_HOST=<railway> SRC_PORT=<porta> SRC_DB=chiefs_intelligence \
SRC_USER=<user> SRC_PASSWORD=<pass> SRC_SSLMODE=prefer \
DST_HOST=<heroku-pg> DST_PORT=5432 DST_DB=<db> \
DST_USER=<credencial> DST_PASSWORD=<pass> DST_SSLMODE=require \
APP_SCHEMA=app \
python3 etl/etl.py --merge 2>&1 | tee evidencia-da-execucao.txt
```

Flags: `--merge-only` (só o merge) · `--validate-only` (só compara, não
escreve). Duração de referência (homolog): **~3 min** (o gargalo é
`chief_embeddings`, ~2 min — vetores 1536).

### Credenciais — quem roda o quê

| Operação | Credencial | Por quê |
|---|---|---|
| Carga das 48 (TRUNCATE+INSERT) | **default** (dona das tabelas) | TRUNCATE exige ownership |
| Merge (UPDATE em `app.*`) | **default/admin** | `intelligence_user` só tem SELECT em `app` |
| Leitura pós-carga (serviço de IA) | `intelligence_user` | grants + default privileges do P1 |
| Origem (Railway) | somente leitura | regra contratual; o script força a sessão READ ONLY |

⚠ `SRC_SSLMODE=prefer`: o proxy TCP do Railway NÃO suporta SSL (constatado
19/08). O destino Heroku segue `require`.

## Pré-requisitos no destino (uma vez por ambiente)

1. `ddl/ddl-main-enrichment.sql` (ALTERs em `app.chiefs`/`app.pipedrive_deals`);
2. `ddl/ddl-intelligence-schema.sql` (48 tabelas + índices + view);
3. Grants do P1 aplicados (`ddl/p1-schemas-roles-grants.sql`).

## Validar depois de cada execução

```bash
# integridade além das contagens (sequences + órfãos das FKs lógicas):
psql "<url-destino>" -v app_schema=app -f etl/04-integridade.sql
```
- Esperado: `INTEGRIDADE: OK`; a saída do etl.py termina em
  `== ZERO DIVERGÊNCIAS ==` e merges com `divergentes=0`.
- Órfãos "AUDITORIA/INFO" refletem a origem (ids fora do pool do main) —
  acompanhar tendência, não reprovar.

## Gates pré-execução e pré-cutover (feedback Chiefs 20/08)

1. **Drift de schema (Achado #1)** — a origem segue em desenvolvimento
   ativo; coluna nova lá que não exista no destino = perda silenciosa.
   Desde 20/08 o `etl.py` faz o **check simétrico e falha alto** (coluna
   a mais na origem = erro; `ETL_ALLOW_SCHEMA_DRIFT=1` rebaixa para WARN
   em emergência consciente). Gates de processo:
   - **D-1 do cutover**: rodar `python3 etl.py --validate-only` — além
     das contagens, ele reporta o **re-diff de colunas** origem × destino
     de todas as 48 tabelas;
   - **Regenerar a DDL de um dump fresco** imediatamente antes do cutover
     (ou aplicar os ALTERs do diff);
   - **Congelar migrations do Intelligence** durante a janela de cutover
     (combinar com o time; drift detectado durante a janela = abortar).
2. **Extensões × search_path × USAGE (Achado #2)** — o Heroku instala
   extensões novas no schema `heroku_ext`; role least-privilege precisa
   de `USAGE` nele e do schema no `search_path`. Antes de qualquer
   cutover, conferir para TODOS os roles novos:
   ```sql
   SELECT e.extname, n.nspname FROM pg_extension e
     JOIN pg_namespace n ON n.oid = e.extnamespace;
   SELECT r.rolname, has_schema_privilege(r.rolname,'heroku_ext','USAGE')
     FROM pg_roles r WHERE r.rolname IN
     ('app_user','intelligence_user','looker_reader','analytical_reader');
   ```
   O `ddl/p1-schemas-roles-grants.sql` (≥20/08) já aplica o grant e o
   `search_path = app, public, heroku_ext`.

## Reprocessar

É **idempotente**: rodar de novo = mesmo estado (TRUNCATE+reload; o merge
reaplica os mesmos valores). Falha no meio = rollback total (transação
única) — basta re-executar. Não há estado intermediário a limpar.

## O que quebra se ninguém cuidar

- **Sequences**: o `setval` é automático na carga; NUNCA inserir manualmente
  nas tabelas de `intelligence` sem passar pela aplicação/ETL.
- **Tabela nova criada pelo ETL/replicação**: precisa nascer legível —
  o `ALTER DEFAULT PRIVILEGES` do P1 cobre objetos criados pela credencial
  default; se outra role criar tabelas, repetir
  `ALTER DEFAULT PRIVILEGES FOR ROLE <criadora> ...` (guia P1 §3).
- **Rotação de credenciais**: atualizar os env vars de quem agenda o ETL
  ANTES do `--force` (runbook de rotação do P1).
- **View `deal_quality_scores`**: depende das colunas `notes` etc. em
  `app.pipedrive_deals` — não remover o enrichment.
- Este ETL é **full load**; o delta incremental (watermarks
  `COALESCE(updated_at, created_at)`, soft deletes) é a evolução prevista —
  ver `data/diff-vs-main.md` §2.

## Troubleshooting (lições das execuções reais)

| Sintoma | Causa/Correção |
|---|---|
| `server does not support SSL` na origem | proxy Railway sem SSL → `SRC_SSLMODE=prefer` |
| `must be able to SET ROLE "postgres"` no DDL | linhas `OWNER TO` de pg_dump — o DDL do repo já está saneado; não regenerar de dump sem limpar |
| `heroku pg:psql < arquivo` não executa nada | CLI v11.9 engole stdin — usar `psql "$(heroku pg:credentials:url ...)"` |
| Validação diverge por poucas linhas com origem ativa | snapshot único exige o `src.commit()` pós-SET (já no etl.py ≥19/08) |
| `permission denied` no merge | credencial sem UPDATE em `app.*` — usar default/admin |

## Registro

Anexar a saída de cada execução real (carga + validação + integridade) ao
diretório de evidências da fase e referenciar no relatório (§11.2).
