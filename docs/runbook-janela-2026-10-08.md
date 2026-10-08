# Janela de cutover — quinta 08/10/2026, 10h–12h BRT (13:00–15:00 UTC)

Destino: **`postgresql-trapezoidal-33655`** (attachment `HEROKU_POSTGRESQL_PINK`,
app `chiefsgroup`). Origem Rails: essential-1 `postgresql-triangular-22490`
(`HEROKU_POSTGRESQL_RED`, hoje `DATABASE_URL`). Origem Intelligence: Railway
`chiefs_intelligence` (só leitura). Tempos entre parênteses = medidos no ensaio
de 06–07/10 (`evidencias/ensaio-2026-10-06/11-resumo-tempos.txt`).

Já feito no trapezoidal (06/10) e que **sobrevive ao pg:copy**: 20 credenciais,
12 memberships, search_path de 16 roles. **Não** sobrevive: grants, owner,
objetos → refeitos abaixo.

Quem faz o quê: **Amelia** = banco (tudo que é `psql`/`heroku pg:*`);
**Renan** = Rails (`maintenance`, `worker`), Railway (variáveis, deploy,
alembic, smoke HTTP), destruição/criação de addon; **Duda** = n8n (pausas,
credenciais nos nodes, religar). GO/NO-GO formal na thread antes do
`maintenance:off`.

## Variáveis (terminal da Amelia)

```bash
setopt interactivecomments
cd ~/Documents/workspace/chiefs/chiefs-db-migration
APP=chiefsgroup
DB=postgresql-trapezoidal-33655
DBVAR=HEROKU_POSTGRESQL_PINK
EV=evidencias/janela-2026-10-08; mkdir -p $EV
T() { echo "$(date -u +%FT%TZ) $*" | tee -a $EV/tempos.txt; }
url() { heroku pg:credentials:url $DB --name $1 -a $APP | grep -oE 'postgres://[^ ]+' | head -1; }
DB_URL=$(url default)
```

## 09:30 · Conferências (T-30)

```bash
heroku pg:info DATABASE_URL -a $APP | head -3 | tee $EV/00-database-url-antes.txt      # triangular
heroku pg:info $DB -a $APP | tee $EV/00-pink-antes.txt                                   # Tables: 0
heroku pg:credentials $DB -a $APP | tee $EV/00-pink-credenciais.txt                       # 21 active
psql "$DB_URL" -Atc "select current_database()" | tee $EV/00-pink-db.txt
heroku pg:backups:schedules -a $APP | tee $EV/00-backup-schedules-antes.txt   # 08/10 06:00 UTC: RED e PINK agendados 03:00 BRT; último backup RED a250 Completed 06:04 UTC
```

Renan: `alembic heads` = 1 (116); nenhuma migration nova; Rails sem migration
pendente (ou avisar). Duda: nó "Persist MQL Candidate" desativado (print).
Mapa node → credencial (Renan, 07/10): Prospect Enrichment (FgM8nZxchDBMnmQ8) →
`n8n_contexto_cliente`; Sales-Ops Cargo (UyppIke5UnjEC69X) → `n8n_fila_salesops`.
Addon do ensaio já destruído (v1335, 07/10 18:48 BRT).

## 09:45 · T-15 — congelar a escrita

- **Duda:** pausar Chiefs Pipeline Automation; desligar webhooks
  `enrich-prospect` e `sales-ops-cargo`; print dos três no canal.
- **Renan:** `heroku ps:scale worker=0 -a chiefsgroup`; `heroku maintenance:on -a chiefsgroup`;
  Intelligence parado de escrever na origem (services pausados, ou variável
  trocada sem deploy até o "banco pronto").
- **Amelia:** conferir que a origem parou de receber escrita (opcional):
  `max(updated_at)` de `pipeline_runs`/`mcp_query_log` no Railway, só leitura.

## 10:00 · Backup, cópia, promoção, attach (Amelia) — (~5 min)

```bash
T "backup inicio"
heroku pg:backups:capture DATABASE_URL -a $APP 2>&1 | tee $EV/01-backup-capture.txt
heroku pg:backups -a $APP | head -5 | tee $EV/01-backups.txt                           # Completed
T "backup fim"
T "pg:copy inicio"
heroku pg:copy DATABASE_URL $DBVAR -a $APP                                               # digitar o que o prompt pedir (ensaio: 56 s)
T "pg:copy fim"
heroku pg:info $DB -a $APP | tee $EV/02-pink-depois-copy.txt                             # Tables: 99
T "promote inicio"
heroku pg:promote $DBVAR -a $APP 2>&1 | tee $EV/03-promote.txt
heroku addons:attach $DB --credential app_user --as DATABASE -a $APP 2>&1 | tee $EV/03-attach-app-user.txt
heroku pg:info DATABASE_URL -a $APP | head -3 | tee $EV/03-database-url-depois.txt      # trapezoidal
T "promote fim"
```

O promote cria uma nova cor para o essential-1 (continua attached; é o
rollback). Após o attach, `DATABASE_URL` é a credencial `app_user` do PINK.
Com `maintenance:on` os restarts de dyno não afetam usuário.

## 10:05 · P1 no banco novo (Amelia) — (2 min 25 s)

```bash
T "P1 inicio"
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public; CREATE EXTENSION IF NOT EXISTS pg_trgm;"
psql "$DB_URL" -c "select extname, extversion, extnamespace::regnamespace from pg_extension order by 1" | tee $EV/04-extensoes.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f "../p1/2.schemas-roles-grants.sql" 2>&1 | tee $EV/04-p1-grants.txt
```

O erro final `permission denied to alter role` (seção 8) é esperado: o
search_path do `app_user` já está na role desde 06/10. Conferir e fechar:

```bash
psql "$DB_URL" -c "select schemaname, count(*) from pg_tables where schemaname in ('public','app') group by 1; select tablename from pg_tables where schemaname='app' and tablename like 'active\_campaign%' order by 1" | tee $EV/04-move-app.txt
psql "$DB_URL" -c "select r.rolname, has_database_privilege(r.rolname, current_database(), 'CONNECT') as connect, s.setconfig from pg_roles r left join pg_db_role_setting s on s.setrole=r.oid where r.rolname in ('app_user','intelligence_user','looker_reader','analytical_reader','tl','worker','rubi','jade','safira','ametista','roma','tokyo','bogota','oslo','raiz','grass','ocean','white','n8n_contexto_cliente','n8n_fila_salesops') order by 1" | tee $EV/04-connect-search-path.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-owner-app.sql 2>&1 | tee $EV/04-owner-app.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-public-usage.sql 2>&1 | tee $EV/04-public-usage.txt
T "P1 fim"
```

Esperado: 97 tabelas em `app`, 0 em `public`, 5 `active_campaign_*`; `connect = t`
nas 20 e search_path preenchido nas 16. Se algum search_path tiver sumido,
rodar `ddl/p2-search-path-agentes.sql` como o usuário (e o do
`intelligence_user`/`app_user`).

## 10:08 · DDL, re-diff, ETL (Amelia) — (~5 min 20 s)

```bash
T "DDL inicio"
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-main-enrichment.sql 2>&1 | tee $EV/05-enrichment.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-intelligence-schema.sql 2>&1 | tee $EV/05-ddl-intelligence.txt
T "DDL fim"
export SRC_HOST=interchange.proxy.rlwy.net SRC_PORT=21225 SRC_DB=chiefs_intelligence SRC_USER=postgres SRC_SSLMODE=prefer
export SRC_PASSWORD='<senha do bloco Intelligence do notes.txt>'
export DST_HOST=$(sed -E 's#postgres://[^@]+@([^:]+):.*#\1#' <<<"$DB_URL") DST_PORT=5432
export DST_DB=$(sed -E 's#.*/##' <<<"$DB_URL") DST_USER=$(sed -E 's#postgres://([^:]+):.*#\1#' <<<"$DB_URL")
export DST_PASSWORD=$(sed -E 's#postgres://[^:]+:([^@]+)@.*#\1#' <<<"$DB_URL") DST_SSLMODE=require APP_SCHEMA=app
T "validate-only inicio"; python3 etl/etl.py --validate-only 2>&1 | tee $EV/06-validate-only.txt; T "validate-only fim"   # 0 DRIFT ou PARAR
T "ETL inicio"; python3 etl/etl.py --merge 2>&1 | tee $EV/06-etl-merge.txt; T "ETL fim"                                   # ZERO DIVERGÊNCIAS
psql "$DB_URL" -v app_schema=app -f etl/04-integridade.sql 2>&1 | tee $EV/06-integridade.txt                             # INTEGRIDADE: OK
T "grants-912 inicio"
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-intelligence-user-minimo.sql 2>&1 | tee $EV/07-912.txt
psql "$(url intelligence_user)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-intelligence-user.sql 2>&1 | tee $EV/07-search-path-intelligence-user.txt
T "grants-912 fim"
```

**DRIFT no validate-only = parar e decidir na thread** (o freeze deve garantir 0).

## 10:20 · "Banco pronto" → Chiefs: Railway, alembic, smoke (Renan) — (ensaio: 22 s + 11 s; com deploys ~10 min)

Mensagem na thread: "Banco pronto. `intelligence_user` do
`postgresql-trapezoidal-33655`; a URL das reservas já aponta para ele."
Renan: troca `DATABASE_URL` ← reserva nos 10 services (+ 3 MCPs), deploy,
`alembic upgrade head` 106 → 116, smoke de grants; posta tempo e resultado.

```bash
T "alembic (Chiefs) inicio"
# ... aguardar ...
T "alembic (Chiefs) fim"
psql "$DB_URL" -c "select version_num from intelligence.alembic_version; select relname, relkind, pg_get_userbyid(relowner) from pg_class where relnamespace='intelligence'::regnamespace and relname in ('chiefs_ativos','chiefs_todos','pipedrive_deals','ac_contacts','ac_campaigns','ac_contact_messages','compat_array_text') order by 1" | tee $EV/08-pos-alembic.txt
```

Esperado: 116 e as 6 views com owner `intelligence_user`.

## 10:35 · Índices, agentes, n8n, testes (Amelia) — (~7 min)

```bash
T "indices inicio"
sed 's/ CONCURRENTLY//' ddl/ddl-main-enrichment-indexes.sql | psql "$DB_URL" -v ON_ERROR_STOP=1 -f - 2>&1 | tee $EV/09-indices.txt
T "indices fim"
T "grants-agentes-n8n inicio"
psql "$DB_URL" -v ON_ERROR_STOP=1 -v ambiente=producao -f ddl/p2-roles-agentes.sql 2>&1 | tee $EV/10-roles-agentes.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-roles-n8n.sql 2>&1 | tee $EV/10-roles-n8n.txt
T "grants-agentes-n8n fim"
APP=$APP DB=$DB AMBIENTE=producao bash scripts/testa-permissoes-agentes.sh | tee $EV/11-teste-agentes.txt   # 360 PASS
APP=$APP DB=$DB bash scripts/testa-permissoes-n8n.sh | tee $EV/11-teste-n8n.txt                             # 45 PASS
```

Em paralelo, **Duda** troca a credencial "PostgreSQL Chiefs" pelos
`n8n_contexto_cliente`/`n8n_fila_salesops` do PINK, node a node, pelo mapa.

## 10:45 · Smoke por conteúdo e backup agendado (Amelia)

```bash
psql "$DB_URL" -c "select 'ac_contacts' v, count(*) from intelligence.ac_contacts union all select 'ac_campaigns', count(*) from intelligence.ac_campaigns union all select 'ac_contact_messages', count(*) from intelligence.ac_contact_messages union all select 'chiefs_ativos', count(*) from intelligence.chiefs_ativos union all select 'pipedrive_deals', count(*) from intelligence.pipedrive_deals" | tee $EV/12-smoke-views.txt
psql "$(url intelligence_user)" -c "explain (analyze, buffers) select id from chief_embeddings order by embedding <=> (select embedding from chief_embeddings where embedding is not null limit 1) limit 10" | tee $EV/12-smoke-hnsw.txt
psql "$DB_URL" -c "select usename, application_name, count(*) from pg_stat_activity where datname = current_database() group by 1, 2 order by 1, 2" | tee $EV/12-conexoes.txt
heroku pg:backups:schedules -a $APP | tee $EV/13-backup-schedules-depois.txt   # PINK já agendado 03:00 BRT (conferido 08/10 06:00 UTC); só verificar
```

Esperado nas conexões: `intelligence_user` (services do Railway), `app_user`
(Rails, após maintenance:off), `n8n_*`; **nenhuma** conexão de app pela
default. Views ≥ 7.091 / 354 / 36.959 / 2.121 / 3.916 (ensaio).

## 11:00 · GO/NO-GO (Renan + Amelia, na thread)

Critérios: ZERO DIVERGÊNCIAS, INTEGRIDADE OK, alembic 116 + views `ac_*`,
360/45 PASS, índices válidos, conexões certas, Railway sem escrita nova
(`max(updated_at)` igual ao de T-15).

**GO →** Renan: `heroku maintenance:off`, `ps:scale worker=<n>`; smoke HTTP do
Intelligence (suite content) e do portal; Duda: religar Pipeline Automation e
webhooks, "Fetch Pending" para o que ficou no Pipedrive. Amelia: conferir
`pg_stat_activity` de novo (`12-conexoes.txt` v2) e `heroku logs -n 200`.

**NO-GO → rollback (até o GO nada foi escrito nas origens):**

```bash
heroku pg:promote HEROKU_POSTGRESQL_RED_URL -a $APP        # Rails de volta ao essential-1 (segundos)
heroku pg:info DATABASE_URL -a $APP | head -3
```

Renan: `DATABASE_URL` dos services de volta ao Railway (sem alembic: a origem
está em 116); maintenance:off. O PINK fica como está para análise.

## Depois do GO

- essential-1 (`postgresql-triangular-22490`) e Railway **intocados até o aceite
  do P3**; nada de `addons:destroy` nem desligamento do serviço Railway.
- Registrar tempos e evidências (`$EV`), commitar sem URL/senha.
- Rotação das credenciais do ensaio: n/a (addon destruído).
- Todo `pg:promote` futuro exige refazer `addons:attach --credential app_user --as DATABASE`.
