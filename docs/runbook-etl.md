# Runbook · ETL intelligence → destino (P2)

Entregável do critério "a Chiefs opera sozinha" (briefing §2). Cobre: como
rodar, quando, com qual credencial, o que monitorar, como reprocessar e o
que quebra se ninguém cuidar. Validado em homolog em 19/08/2026 (348 mil+
linhas, zero divergências, origem viva).

## O que o ETL faz

1. **Carga full** (espelho 1:1) das tabelas que nascem no Intelligence →
   schema `intelligence` do Postgres principal: **48 recarregadas** (TRUNCATE
   sem CASCADE + INSERT, transação única, `setval` das 43 sequences) +
   `alembic_version` semeada só na 1ª carga; passo final: owner de
   `intelligence.*` → `intelligence_user` (feedback 08/09, itens 4 e 5);
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
| Carga das 48 (TRUNCATE+INSERT) | **default** | TRUNCATE exige ser owner **ou membro do owner**: após o passo de owner, a default opera por ser membro de `intelligence_user` (`rolinherit`; conferido na homolog 08/09) — o `etl.py` checa isso antes de truncar |
| Merge (UPDATE em `app.*`) | **default/admin** | `intelligence_user` só tem SELECT em `app` + UPDATE nas 53 colunas de enriquecimento (item 1) |
| Owner de `intelligence.*` → `intelligence_user` (item 5) | **default** | ALTER OWNER exige ser owner atual e membro da role destino; passo final do `etl.py` / `05-owner-intelligence.sql` |
| `GRANT UPDATE` por coluna em `app.chiefs` (item 1) e índices (item 3) | **default** (owner de `app.chiefs`) | `ddl/p2-grants-enrichment-update.sql`, `ddl/ddl-main-enrichment-indexes.sql` |
| `search_path` da role (item 2) | **o próprio `intelligence_user`** | a default não tem CREATEROLE no Heroku ("permission denied to alter role", P1 19/08) |
| Migrations Alembic do Intelligence (ALTER TABLE, CREATE INDEX no schema) | `intelligence_user` | precisa ser OWNER dos objetos — por isso o item 5 |
| Leitura/escrita pós-carga (serviço de IA) | `intelligence_user` | grants + default privileges do P1 |
| Origem (Railway) | somente leitura | regra contratual; o script força a sessão READ ONLY |

⚠ `SRC_SSLMODE=prefer`: o proxy TCP do Railway NÃO suporta SSL (constatado
19/08). O destino Heroku segue `require`.

## Pré-requisitos no destino (uma vez por ambiente)

1. `ddl/ddl-main-enrichment.sql` (ALTERs em `app.chiefs`/`app.pipedrive_deals`);
2. `ddl/ddl-intelligence-schema.sql` (49 tabelas + índices + view) — **regenerar/re-diffar contra a origem no D-1** (08/09: origem em alembic 106, +`chief_perfil_perguntas`, +5 colunas em `job_descriptions`);
3. Grants do P1 aplicados (`ddl/p1-schemas-roles-grants.sql`);
4. Grants de cutover (feedback 08/09): `ddl/p2-grants-enrichment-update.sql`
   (item 1, como default), `ddl/p2-search-path-intelligence-user.sql` (item 2,
   como `intelligence_user`), `ddl/ddl-main-enrichment-indexes.sql` (item 3,
   produção).

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

## Reprocessar — re-execução D-1 (passo a passo)

É **idempotente**: rodar de novo = mesmo estado (TRUNCATE+reload; o merge
reaplica os mesmos valores). Falha no meio = rollback total (transação
única) — basta re-executar. Não há estado intermediário a limpar.

Cenário do teste de cutover (feedback 08/09, item 4): o Intelligence já
rodou migrations no schema `intelligence` do destino (views
`chiefs_todos`/`chiefs_ativos` por cima de `app.chiefs`, tabela
`chief_perfil_perguntas`, colunas `is_test`/`outcome*`, `alembic_version`
em 107) e a re-execução antes da promoção precisa **não destruir isso**.
Garantias do `etl.py` (≥ 08/09), provadas no passo 9 da validação local:

| Garantia | Como |
|---|---|
| Só recarrega as 48 tabelas de `TABLES` | `TRUNCATE <lista explícita> RESTART IDENTITY` **sem CASCADE** + INSERT; não existe `DROP`/`CREATE` no ETL (o DDL é passo separado, só na 1ª vez, e falha se a tabela já existir) |
| Não reescreve `intelligence.alembic_version` | fora de `TABLES`; `seed_alembic_version` só insere se a tabela estiver vazia; a validação mostra origem × destino como INFO, não como divergência |
| Views/tabelas/funções/colunas novas do Intelligence intactas | não estão na lista → não são tocadas; coluna nova só no destino é tolerada (INFO) e fica com o DEFAULT; `reset_sequences` só olha as 48 |
| Grants e default privileges preservados | nada é dropado/recriado; `ALTER OWNER` mantém ACLs |
| Owner final `intelligence_user` | `ensure_owner` (idempotente) no fim da transação; SQL equivalente em `05-owner-intelligence.sql` |
| Falha alto quando precisa | tabela nova na origem sem veredito; coluna só na origem (drift); FK de tabela do cliente para uma das 48 |

⚠ O que a re-execução **substitui**: o conteúdo das 48 tabelas no destino
(inclusive `users`, `ui_access_grant`, `system_prompts`, `chief_perfil_perguntas`)
volta a ser o da origem — escrita feita pelo app **no destino** durante o
teste, nessas tabelas, é descartada por desenho (até o cutover a origem é a
verdade). Combinar o momento com o time.

Passo a passo (D-1, destino = banco do cutover):

```bash
# 0) congelar migrations do Intelligence e pausar gravadores (n8n) na janela
# 1) re-diff de schema + contagens, sem escrever nada:
python3 etl/etl.py --validate-only            # DRIFT = parar e aplicar ALTER/DDL antes
# 2) carga + merge + owner (credencial DEFAULT), com evidência:
python3 etl/etl.py --merge 2>&1 | tee evidencia-rerun-D-1.txt
#    esperado: "alembic_version: preservada", "owner → intelligence_user: 0 objeto(s)"
#    (já eram), "== ZERO DIVERGÊNCIAS =="
# 3) integridade:
psql "$DST_URL" -v app_schema=app -f etl/04-integridade.sql
# 4) o Intelligence roda `alembic upgrade head` (no-op se nada pendente) e faz smoke test
```

## O que quebra se ninguém cuidar

- **Sequences**: o `setval` é automático na carga; NUNCA inserir manualmente
  nas tabelas de `intelligence` sem passar pela aplicação/ETL.
- **Tabela nova criada pelo ETL/replicação**: precisa nascer legível —
  o `ALTER DEFAULT PRIVILEGES` do P1 cobre objetos criados pela credencial
  default; se outra role criar tabelas, repetir
  `ALTER DEFAULT PRIVILEGES FOR ROLE <criadora> ...` (guia P1 §3).
- **Tabela nova na ORIGEM** (migration do Intelligence): pela regra de
  13/08 o que nasce no Intelligence migra — entra em `TABLES` do `etl.py`,
  no `00-fdw-setup.sql`/`01-load`/`03-validate` e no DDL. O `etl.py` falha
  alto enquanto não houver veredito (08/09: `chief_perfil_perguntas` entrou).
- **`GRANT UPDATE` por coluna** (item 1) NÃO é coberto por default
  privileges: coluna nova de enriquecimento em `app.chiefs` exige repetir o
  GRANT (`ddl/p2-grants-enrichment-update.sql`).
- **Índices de expressão com `intelligence.compat_csv_split`** (candidatos
  do item 3): criam dependência `app.chiefs` → função do schema
  `intelligence`; `CREATE OR REPLACE` da função continua ok, `DROP FUNCTION`
  passa a falhar enquanto os índices existirem.
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
| `must be owner of table ...` no deploy do Intelligence | objetos de `intelligence.*` com owner da default — `etl/05-owner-intelligence.sql` (o `etl.py` ≥ 08/09 já faz) |
| `sem TRUNCATE em intelligence...` no início da carga | credencial não é owner nem membro de `intelligence_user` — usar a default (membro) ou `GRANT intelligence_user TO <credencial>` |
| `cannot truncate a table referenced in a foreign key constraint` | tabela do Intelligence com FK para uma das 48: ela nasce lá → entra em `TABLES`; nunca voltar o CASCADE |
| `tabelas NOVAS na origem sem veredito` | decidir: `TABLES` (+DDL) ou `ORIGIN_EXCLUDED`; backups `_bak_/_backup_YYYYMMDD` só avisam |

## Registro

Anexar a saída de cada execução real (carga + validação + integridade) ao
diretório de evidências da fase e referenciar no relatório (§11.2).
