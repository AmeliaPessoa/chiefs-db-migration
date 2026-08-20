# chiefs-db-migration

ETL e DDLs da consolidação de bancos **Iarandu × Chiefs** (fases P2/P3):
migração do banco do serviço de inteligência (Railway) para o schema
`intelligence` do Postgres principal (Heroku), com merge do enriquecimento
nas tabelas do main. Este repositório cumpre o critério contratual de
**fonte única versionada** (briefing, Anexo I).

**Validado em homologação em 19/08/2026**: 358.844 linhas, 48/48 tabelas,
zero divergências, com a origem viva recebendo escrita durante a carga;
re-execução idempotente comprovada.

---

## O que o ETL faz

Desenho definido pelos vereditos de 13/08 (Renan): **tabela espelho não
migra — só migra o que nasce no Intelligence**.

1. **Carga full, espelho 1:1, das 48 tabelas** que nascem no Intelligence
   → schema `intelligence` do destino. `TRUNCATE ... RESTART IDENTITY
   CASCADE` + INSERT por streaming COPY→COPY **em memória** (nenhum dado
   toca disco — regra §5.1), `setval` das 42 sequences, tudo em **uma
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
  ddl-intelligence-schema.sql  schema intelligence: 48 tabelas, 42 sequences, índices (3 HNSW), view
  p1-schemas-roles-grants.sql  schemas/roles/grants do P1 (inclui heroku_ext — Achado #2 de 20/08)
  main-schema-snapshot.sql     snapshot schema-only do main (canônico: migrations do Rails; snapshot de 11/08)
etl/
  etl.py                       ETL recomendado: carga + merge + validação (streaming em memória)
  00-fdw-setup.sql             alternativa SQL: conexão read-only com a origem via postgres_fdw
  01-load-intelligence.sql     alternativa SQL: carga das 48 em ordem de FK + setval
  02-merge-main.sql            alternativa SQL: merge das híbridas + relatório de fidelidade
  03-validate.sql              contagens 48/48 origem × destino
  04-integridade.sql           sequences (check duro) + órfãos das FKs lógicas (auditoria)
scripts/
  run-local-validation.sh      validação local em Docker (pgvector/pg17) a partir de dumps
docs/
  runbook-etl.md               runbook de operação (credenciais, monitoração, gates pré-cutover, troubleshooting)
evidencias/
  p1/  p2/  feedback-2026-08-20/   evidências das execuções em homolog (critério "com evidência" do §11.1)
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

### 2 · Carga + merge + validação

```bash
python3 etl/etl.py --merge
```

Saída esperada: 48 tabelas carregadas, linhas de merge com
`divergentes=0`, `Commit OK — 42 sequences reposicionadas` e
`== ZERO DIVERGÊNCIAS ==`. Duração de referência: **~3 min** (gargalo:
`chief_embeddings`, vetores 1536).

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
```

### Validação local em Docker (não toca bases reais)

```bash
DUMP_INTEL=/caminho/dump-intelligence.sql \
DUMP_MAIN=/caminho/dump-main.sql \
bash scripts/run-local-validation.sh
```

## Reprocessamento e idempotência

Rodar de novo = mesmo estado final (carga é TRUNCATE+reload; o merge
reaplica os mesmos valores). Falha no meio = rollback total. Não há
estado intermediário a limpar. Detalhes operacionais (monitoração, o que
quebra se ninguém cuidar, troubleshooting): **`docs/runbook-etl.md`**.

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
| `heroku pg:psql < arquivo` não executa nada | CLI v11.9 engole stdin → usar `psql "$DST_URL" -f` |
