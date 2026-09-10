# chiefs-db-migration

ETL e DDLs da consolidação de bancos **Iarandu × Chiefs** (fases P2/P3):
migração do banco do serviço de inteligência (Railway) para o schema
`intelligence` do Postgres principal (Heroku), com merge do enriquecimento
nas tabelas do main. Este repositório cumpre o critério contratual de
**fonte única versionada** (briefing, Anexo I).

**Validado em homologação em 19/08/2026**: 358.844 linhas, 48/48 tabelas,
zero divergências, com a origem viva recebendo escrita durante a carga;
re-execução idempotente comprovada. **08/09/2026** (feedback do teste de
cutover em homolog): re-diff da origem (alembic 106) incorporado —
49 tabelas —, re-execução D-1 que **preserva** o que o Intelligence cria no
schema, e owner final `intelligence_user` (ver "Re-execução D-1").

---

## O que o ETL faz

Desenho definido pelos vereditos de 13/08 (Renan): **tabela espelho não
migra — só migra o que nasce no Intelligence**.

1. **Carga full, espelho 1:1, das tabelas que nascem no Intelligence**
   → schema `intelligence` do destino: 49 no schema (48 + `alembic_version`,
   que é semeada na 1ª carga e **nunca sobrescrita** depois). `TRUNCATE
   ... RESTART IDENTITY` (**sem CASCADE**) + INSERT por streaming COPY→COPY
   **em memória** (nenhum dado toca disco — regra §5.1), `setval` das 43
   sequences, owner dos objetos → `intelligence_user`, tudo em **uma
   transação** (falha = rollback total; re-executar nunca duplica).
2. **Merge das híbridas** no main:
   - `app.chiefs` **+53 colunas** de enriquecimento — fonte
     `chiefs_ativos ∪ chiefs_todos`, em conflito **vale `chiefs_ativos`**;
   - `app.pipedrive_deals` **+4 colunas** (`notes`, `files`,
     `origem_oportunidade`, `utm_source`) — match por
     `app.pipedrive_deals.pipedrive_id = intel.pipedrive_deals.id`.
   - O merge **só escreve as colunas novas** (nunca sobrescreve valor do
     main); ids sem correspondência são **descartados e contabilizados**.
3. **Validação**: contagens origem × destino das 48 sob **um único
   snapshot REPEATABLE READ** (confiável mesmo com gravadores ativos na
   origem) + fidelidade do merge por ROW compare + testes de integridade
   (`etl/04-integridade.sql`).

## Estrutura do repositório

```
ddl/
  ddl-main-enrichment.sql      ALTER TABLE no main: chiefs +53, pipedrive_deals +4 (idempotente)
  ddl-main-enrichment-indexes.sql  índices em app.chiefs p/ o enrichment (mínimo p/ produção + candidatos GIN) — feedback 08/09 item 3
  ddl-intelligence-schema.sql  schema intelligence: 49 tabelas, 43 sequences, índices (3 HNSW), view (re-diff 08/09: alembic 106)
  p1-schemas-roles-grants.sql  schemas/roles/grants do P1 (inclui heroku_ext — Achado #2 de 20/08)
  p2-grants-enrichment-update.sql  GRANT UPDATE por coluna (53) em app.chiefs → intelligence_user — feedback 08/09 item 1
  p2-search-path-intelligence-user.sql  search_path da role intelligence_user (rodar COMO a role) — feedback 08/09 item 2
  main-schema-snapshot.sql     snapshot schema-only do main (canônico: migrations do Rails; snapshot de 11/08)
  intelligence-origin-schema.sql  snapshot schema-only da ORIGEM (regenerado 08/09 — alembic 106; regenerar no gate D-1)
etl/
  etl.py                       ETL recomendado: carga + merge + validação + owner (streaming em memória)
  00-fdw-setup.sql             alternativa SQL: conexão read-only com a origem via postgres_fdw
  01-load-intelligence.sql     alternativa SQL: carga das 48 em ordem de FK + setval (alembic_version só se vazia)
  02-merge-main.sql            alternativa SQL: merge das híbridas + relatório de fidelidade
  03-validate.sql              contagens 48/48 origem × destino (+ versão alembic à parte)
  04-integridade.sql           sequences (check duro) + órfãos das FKs lógicas (auditoria)
  05-owner-intelligence.sql    passo final: owner de intelligence.* → intelligence_user — feedback 08/09 item 5
scripts/
  run-local-validation.sh      validação local em Docker (pgvector/pg17) — modo sintético §5.1 + cenário de re-execução D-1
docs/
  runbook-etl.md               runbook de operação (credenciais, monitoração, gates pré-cutover, re-execução D-1, troubleshooting)
evidencias/
  p1/  p2/  feedback-2026-08-20/  feedback-2026-09-08/   evidências das execuções (critério "com evidência" do §11.1)
.env.example                   modelo das variáveis de conexão (copiar para .env)
```

## Pré-requisitos

- **Python 3.10+** com `psycopg2`: `pip3 install psycopg2-binary`
- **psql** (libpq) para os DDLs e scripts SQL
- No **destino**: extensão `pgvector` disponível (Heroku: allowlisted a
  partir do plano Standard) e os grants/roles do P1 aplicados
  (`app_user`, `intelligence_user`, `looker_reader`, `analytical_reader`)
- Acesso de rede à origem (Railway) e ao destino (Heroku)

## Configuração — variáveis de ambiente

**Nenhuma credencial vive no código ou no repositório.** Tudo entra por
variável de ambiente:

```bash
cp .env.example .env     # preencha o .env (está no .gitignore)
set -a; source .env; set +a
```

| Variável | Obrigatória | Descrição |
|---|---|---|
| `SRC_HOST` / `SRC_PORT` / `SRC_DB` | ✅ | Origem: Intelligence DB (Railway) |
| `SRC_USER` / `SRC_PASSWORD` | ✅ | Credencial da origem — usada **somente para leitura** (o ETL força a sessão `READ ONLY`) |
| `SRC_SSLMODE` | — | `prefer` (default) — o proxy TCP do Railway **não suporta SSL**; `require` falha |
| `DST_HOST` / `DST_PORT` / `DST_DB` | ✅ | Destino: Postgres principal (Heroku) |
| `DST_USER` / `DST_PASSWORD` | ✅ | **Credencial `default`** do banco (dona das tabelas). `intelligence_user` NÃO serve para a carga (TRUNCATE exige ownership) nem para o merge (não tem UPDATE em `app`) |
| `DST_SSLMODE` | — | `require` (default no .env.example) — obrigatório no Heroku |
| `DST_SCHEMA` | — | default `intelligence` |
| `DST_OBJECT_OWNER` | — | default `intelligence_user`: owner final de tabelas/sequences/views de `DST_SCHEMA` (passo final da carga; vazio = não alterar) |
| `APP_SCHEMA` | — | default `app`; usar `public` em bancos restaurados de dump (validação local) |
| `DST_URL` | scripts psql | Connection string montada, para os passos com `psql -f` |
| `DUMP_INTEL` / `DUMP_MAIN` | validação local | Caminhos dos dumps locais (não versionados) |

No Heroku, a credencial default é obtida com:
`heroku pg:credentials:url DATABASE_URL --name default -a <app>`.

## Como rodar do zero

### 1 · DDLs no destino (uma vez por ambiente)

```bash
DST_URL="postgres://$DST_USER:$DST_PASSWORD@$DST_HOST:$DST_PORT/$DST_DB"

psql "$DST_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-main-enrichment.sql
psql "$DST_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-intelligence-schema.sql
```

> O `ddl-main-enrichment.sql` assume as tabelas do monolito no schema
> `app` (pós-P1). Em base restaurada de dump (tabelas em `public`),
> troque o `SET search_path` no topo do arquivo.

### 1b · Grants de cutover para `intelligence_user` (uma vez por ambiente — feedback 08/09)

O serviço de inteligência passa a gravar o enriquecimento **direto em
`app.chiefs`** e a rodar suas migrations Alembic no schema `intelligence`:

```bash
# item 1 — UPDATE só nas 53 colunas de enriquecimento (credencial DEFAULT, owner de app.chiefs)
psql "$DST_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-enrichment-update.sql

# item 2 — search_path da role: rodar CONECTADO COMO intelligence_user (a default não altera roles no Heroku)
psql "$(heroku pg:credentials:url DATABASE_URL --name intelligence_user -a <app> | grep -oE 'postgres://[^ ]+')" \
     -v ON_ERROR_STOP=1 -f ddl/p2-search-path-intelligence-user.sql

# item 3 — índices em app.chiefs (produção; CONCURRENTLY, fora de transação)
psql "$DST_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-main-enrichment-indexes.sql
```

O item 5 (owner de `intelligence.*` = `intelligence_user`) é passo final
automático do `etl.py`; no caminho 100% SQL, rodar `etl/05-owner-intelligence.sql`.

### 1c · Lado Rails no mesmo banco (uma vez por ambiente — feedback 10/09)

O `rails db:migrate` do release phase roda como `app_user` (DATABASE_URL) e
exige ser OWNER para `ALTER TABLE` — as 97 tabelas movidas no P1 ficaram
com a credencial default (v251/v252 na homolog: `must be owner of table
chiefs`). Mesmo desenho do item 5, do outro lado (decisão (A), 10/09):

```bash
# item 6 — owner de app.* → app_user (BLOQUEANTE do deploy Rails; credencial DEFAULT)
psql "$DST_URL" -v ON_ERROR_STOP=1 -f ddl/p2-owner-app.sql

# item 7 — USAGE em public/heroku_ext para as 4 roles (pg_trgm/vector estão em public;
#          sem USAGE o search_path descarta o schema em silêncio: "function similarity(...) does not exist")
psql "$DST_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-public-usage.sql

# item 8 — ANALYZE em app + intelligence (o etl.py já faz ao fim da carga; este é o avulso)
psql "$DST_URL" -v ON_ERROR_STOP=1 -f etl/06-analyze.sql
```

Nenhum passo do ETL toca owner de `app.*` (o `ensure_owner` só olha o
schema `intelligence`; o merge é UPDATE; o DDL do enrichment é ADD COLUMN)
— o bloco do item 6 é one-off por ambiente, e a default continua operando
`app.*` por ser membro de `app_user`.

### 2 · Carga + merge + validação

```bash
python3 etl/etl.py --merge
```

Saída esperada: 48 tabelas carregadas, `alembic_version: semeada da origem`
(1ª carga) ou `preservada` (re-execução), linhas de merge com
`divergentes=0`, `Commit OK — 43 sequences reposicionadas; owner →
intelligence_user: N objeto(s) alterado(s); ANALYZE em 50 tabela(s)` e
`== ZERO DIVERGÊNCIAS ==`. Duração de referência: **~3 min** (gargalo:
`chief_embeddings`, vetores 1536). `ETL_SKIP_ANALYZE=1` pula o ANALYZE
(não recomendado — feedback 10/09, item 8).

Flags:

| Flag | Efeito |
|---|---|
| *(sem flag)* | só a carga das 48 (sem tocar o schema `app`) |
| `--merge` | carga + merge das híbridas |
| `--merge-only` | só o merge (não toca o schema `intelligence`) |
| `--validate-only` | só compara contagens; não escreve nada |

### 3 · Integridade (pós-carga)

```bash
psql "$DST_URL" -v app_schema=$APP_SCHEMA -f etl/04-integridade.sql
```

Esperado: `INTEGRIDADE: OK`. Checks **duros**: sequence atrás do
`MAX(id)` reprova. Órfãos das FKs lógicas (`chief_id`, `deal_id`,
`jd_id`, `rails_vaga_id`) são **auditoria** — refletem a origem, não
reprovam a carga.

### Alternativa 100% SQL (via postgres_fdw, sem Python)

```bash
psql "$DST_URL" -f etl/00-fdw-setup.sql \
  -v src_host=$SRC_HOST -v src_port=$SRC_PORT -v src_db=$SRC_DB \
  -v src_user=$SRC_USER -v src_pass=$SRC_PASSWORD
psql "$DST_URL" -v ON_ERROR_STOP=1 -f etl/01-load-intelligence.sql
psql "$DST_URL" -v ON_ERROR_STOP=1 -v app_schema=$APP_SCHEMA -f etl/02-merge-main.sql
psql "$DST_URL" -f etl/03-validate.sql
psql "$DST_URL" -v ON_ERROR_STOP=1 -f etl/05-owner-intelligence.sql   # passo final (item 5)
psql "$DST_URL" -v ON_ERROR_STOP=1 -f etl/06-analyze.sql               # estatísticas (item 8, 10/09)
```
(o `01-load` e o `02-merge` já fazem ANALYZE nas tabelas que tocam; o `06`
cobre os dois schemas inteiros)

### Validação local em Docker (não toca bases reais — §5.1)

```bash
bash scripts/run-local-validation.sh
```

**Modo padrão: SINTÉTICO** — origem e destino criados de schema-only
(snapshots em `ddl/`) + seed sintético gerado pelo próprio script
(nenhum dado real na máquina local). Exercita carga das 48, merge com
conflito ativos×todos e ids sem match, sequences, view, contagens,
integridade e, no passo 9, a **re-execução D-1 com o `etl.py`** no cenário
do teste de cutover (view, tabela, coluna e `alembic_version` criadas pelo
Intelligence no schema precisam sobreviver; owner final `intelligence_user`). Modo legado com dumps reais: `USE_REAL_DUMPS=1
DUMP_INTEL=... [DUMP_MAIN=...]` — somente em ambiente autorizado.

## Reprocessamento e idempotência — re-execução D-1

Rodar de novo = mesmo estado final (carga é TRUNCATE+reload; o merge
reaplica os mesmos valores). Falha no meio = rollback total. Não há
estado intermediário a limpar.

O que a re-execução (ex.: D-1 do cutover, com o Intelligence já rodando
migrations no schema `intelligence` do destino) **toca** e o que **preserva**
(feedback 08/09, item 4 — provado no passo 9 da validação local):

| | |
|---|---|
| **Recarrega** (TRUNCATE + INSERT, sem CASCADE) | só as 48 tabelas de `TABLES` no `etl.py` (lista idêntica ao `01-load-intelligence.sql`) — dado gravado pelo app nelas, no destino, é substituído pelo da origem |
| **Nunca sobrescreve** | `intelligence.alembic_version` (só semeia se vazia); colunas que existem só no destino (ficam com o DEFAULT) |
| **Não toca** | views (`chiefs_todos`, `chiefs_ativos`, `deal_quality_scores`), funções, tabelas fora da lista (ex.: `mcp_refresh_tokens`), grants, default privileges, o schema em si — não há `DROP`/`CREATE` no ETL; o DDL é passo separado e só da 1ª vez |
| **Falha alto** | tabela nova na origem sem veredito; coluna nova na origem ausente no destino (drift, Achado #1); tabela do cliente com FK para uma das 48 (TRUNCATE sem CASCADE recusa) |
| **Passo final** | owner de tabelas/sequences/views de `intelligence` → `intelligence_user` (idempotente) + ANALYZE nas tabelas tocadas (10/09) |

Detalhes operacionais (monitoração, o que quebra se ninguém cuidar,
troubleshooting): **`docs/runbook-etl.md`**.

## Segurança e regras contratuais

- Origem **somente leitura** (sessão forçada `READ ONLY`);
- Nenhum dado toca disco/repositório — streaming em memória (§5.1);
- **PII/financeiro fora do escopo**: `chief_accounts`, `credit_cards`,
  CPF/CNPJ e tokens não participam de carga nem merge;
  `mcp_refresh_tokens` nunca é propagada;
- `.env` no `.gitignore` — **jamais commitar credenciais**; rotação de
  credenciais: runbook do P1.

## Troubleshooting rápido

| Sintoma | Causa / solução |
|---|---|
| `server does not support SSL` na origem | proxy Railway sem SSL → `SRC_SSLMODE=prefer` |
| `must be able to SET ROLE "postgres"` | DDL regenerado de pg_dump com `OWNER TO` — os DDLs deste repo já estão saneados |
| `permission denied for table ...` na carga/merge | credencial errada → usar a **default** (dona) |
| Validação diverge por poucas linhas com origem ativa | usar o `etl.py` deste repo (≥19/08: snapshot único corrigido) |
| `DRIFT DE SCHEMA` na carga | coluna nova na origem (migration recente) ausente no destino — aplicar o ALTER/DDL e re-rodar; `--validate-only` é o re-diff do D-1 (Achado #1, 20/08); `ETL_ALLOW_SCHEMA_DRIFT=1` só em emergência consciente |
| `tabelas NOVAS na origem sem veredito` | migration do Intelligence criou tabela nova — decidir: entra em `TABLES` (+ DDL) ou em `ORIGIN_EXCLUDED` |
| `must be owner of table ...` no deploy do Intelligence | objetos de `intelligence.*` ainda com owner da credencial default — rodar `etl/05-owner-intelligence.sql` (o `etl.py` já faz ao fim da carga) |
| `must be owner of table chiefs` no release phase do **Rails** (`db:migrate`) | `app.*` com owner da default e `DATABASE_URL = app_user` — rodar `ddl/p2-owner-app.sql` (item 6, 10/09); one-off por ambiente, inclusive produção após o P1 |
| `function similarity(...) does not exist` / `unaccent(...)` no Rails ou BI | role sem USAGE em `public`/`heroku_ext` (o search_path descarta o schema sem erro) — `ddl/p2-grants-public-usage.sql` (item 7, 10/09) |
| Planos ruins logo após a carga (seq scan em tudo) | estatísticas zeradas por TRUNCATE+COPY — `etl/06-analyze.sql` (o `etl.py` ≥ 10/09 já faz) |
| `cannot truncate a table referenced in a foreign key constraint` | tabela do Intelligence com FK para uma das 48 — sinal de que ela nasce lá e precisa entrar em `TABLES`; nunca usar CASCADE |
| `heroku pg:psql < arquivo` não executa nada | CLI v11.9 engole stdin → usar `psql "$DST_URL" -f` |
