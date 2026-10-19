# Aplicar 19/10: chief_ads + 2ª view + #912, view em PROD, índice Industry, knowledge (HML), monitoramento

Respostas do Renan de 19/10. **Só a Amelia executa.** HML primeiro; em PROD só o
que o Renan já liberou por escrito (view `chief_status_versions` e, por extensão,
a reconciliação do #912; o índice Industry é aditivo). `knowledge` em PROD e
`monitoramento` em PROD só depois do OK dele.

```bash
setopt interactivecomments
cd ~/Documents/workspace/chiefs/chiefs-db-migration
EV=evidencias/pos-cutover-2026-10-19; mkdir -p $EV
url() { heroku pg:credentials:url $DB --name $1 -a $APP | grep -oE 'postgres://[^ ]+' | head -1; }
```

## HML

```bash
APP=chiefsgroup-homolog; DB=postgresql-fluffy-10310; AMB=hml
DB_URL=$(url default); psql "$DB_URL" -Atc "select current_database()"      # devpemtfal8rfl
```

### 1 · Views (re-run: acrescenta chief_versions_meta) e #912 (acrescenta chief_ads)

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-view-chief-status-versions.sql 2>&1 | tee $EV/01-views-$AMB.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-intelligence-user-minimo.sql 2>&1 | tee $EV/02-912-$AMB.txt
```

Esperado: `COMMIT` nos dois; #912 com **6** linhas table-level (3 `active_campaign_*`,
`chief_ads`, `chief_status_versions`, `chief_versions_meta`), **28 relações / 448
colunas**, 53 UPDATE, PII `f`. Se abortar, nada mudou.

### 2 · Índice Industry que a view usa (CONCURRENTLY) + EXPLAIN antes/depois

```bash
psql "$(url intelligence_user)" -c "explain (analyze, buffers, costs off) SELECT c.id FROM chiefs_ativos c WHERE c.is_deleted = false AND (intelligence.compat_array_text(c.industries_experience) ILIKE '%Fintech%' OR intelligence.compat_array_text(c.industries_experience) ILIKE '%Serviços Financeiros%') LIMIT 100" 2>&1 | tee $EV/03-explain-antes-$AMB.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-indice-industry-view.sql 2>&1 | tee $EV/03-indice-industry-$AMB.txt
psql "$(url intelligence_user)" -c "explain (analyze, buffers, costs off) SELECT c.id FROM chiefs_ativos c WHERE c.is_deleted = false AND (intelligence.compat_array_text(c.industries_experience) ILIKE '%Fintech%' OR intelligence.compat_array_text(c.industries_experience) ILIKE '%Serviços Financeiros%') LIMIT 100" 2>&1 | tee $EV/03-explain-depois-$AMB.txt
```

Esperado: antes `Seq Scan on chiefs`; depois `Bitmap Index Scan on
idx_app_chiefs_industries_compat_trgm`. A query com `::text` (forma atual do
código) continua em Seq Scan: é a reescrita do braço que destrava.

### 3 · knowledge (HML, smoke) — credencial primeiro

```bash
heroku pg:credentials:create $DB --name knowledge_app -a $APP
heroku pg:credentials $DB -a $APP | grep -A1 knowledge_app            # até active; NÃO fazer addons:attach
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-knowledge.sql 2>&1 | tee $EV/04-knowledge-$AMB.txt
psql "$(url knowledge_app)" -v ON_ERROR_STOP=1 -f ddl/p3-knowledge-app-settings.sql 2>&1 | tee $EV/04-knowledge-app-settings-$AMB.txt
psql "$(url rubi)" -v ON_ERROR_STOP=1 -c "SET ROLE tl; CREATE TABLE knowledge._prova (id int); RESET ROLE;" -c "select relname, pg_get_userbyid(relowner) owner, has_table_privilege('knowledge_app','knowledge._prova','INSERT') ka_insert, has_table_privilege('knowledge_app','knowledge._prova','DELETE') ka_delete, has_table_privilege('analytical_reader','knowledge._prova','SELECT') ar_select, has_table_privilege('intelligence_user','knowledge._prova','SELECT') iu_select from pg_class where relname='_prova'" -c "SET ROLE tl; DROP TABLE knowledge._prova;" 2>&1 | tee $EV/04-prova-knowledge-$AMB.txt
psql "$(url knowledge_app)" -c "show statement_timeout" -c "show search_path" -c "select 1 from app.chiefs limit 1" 2>&1 | tee $EV/04-knowledge-app-smoke-$AMB.txt
```

Esperado: `tl` create `t`; `knowledge_app` usage `t`, create `f`; owner `tl`,
`ka_insert t`, `ka_delete f`, `ar_select t`, `iu_select f`; como `knowledge_app`:
`statement_timeout = 30s`, search_path `knowledge, intelligence, public, heroku_ext`,
e `permission denied for schema app`. A seção 4 (views de `intelligence`) fica
comentada até a lista chegar com o DDL.

### 4 · Monitoramento para o tl

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-monitoramento-tl.sql 2>&1 | tee $EV/05-monitoramento-$AMB.txt
psql "$(url rubi)" -c "select * from lab.mon_conexoes()" -c "select credencial, calls, total_exec_ms, left(query, 60) q from lab.mon_statements(5)" 2>&1 | tee $EV/05-monitoramento-rubi-$AMB.txt
psql "$(url jade)" -c "select * from lab.mon_conexoes()" 2>&1 | tee $EV/05-monitoramento-jade-negado-$AMB.txt
```

Esperado: NOTICE dizendo se `pg_read_all_stats` foi concedido ou negado; `tl` com
EXECUTE `t`, demais `f`; rubi vê as credenciais e as queries; jade recebe
`permission denied for function` (ou `for schema lab`).

## PROD (liberado por escrito em 19/10: view; o #912 reconcilia chief_ads; índice é aditivo)

```bash
APP=chiefsgroup; DB=postgresql-trapezoidal-33655; AMB=prod
DB_URL=$(url default); psql "$DB_URL" -Atc "select current_database()"      # dfiit9c72iv839
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-view-chief-status-versions.sql 2>&1 | tee $EV/01-views-$AMB.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-intelligence-user-minimo.sql 2>&1 | tee $EV/02-912-$AMB.txt
psql "$(url intelligence_user)" -c "select count(*) from app.chief_status_versions" -c "select count(*) from app.chief_versions_meta" -c "select 1 from app.versions limit 1" 2>&1 | tee $EV/01-views-como-intelligence-user-$AMB.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-indice-industry-view.sql 2>&1 | tee $EV/03-indice-industry-$AMB.txt
```

Esperado: #912 6 / 28 / 448 / 53; views contam e `app.versions` dá `permission
denied`; índice válido. `knowledge` e `monitoramento` em PROD: só após o OK do
Renan (até 30/10).

## Depois

Avisar na thread (números de PROD das views e do #912, EXPLAIN antes/depois,
`knowledge` pronto na HML, monitoramento); registrar em `p2/0. p2-entregas.md`;
commitar `ddl/p3-*.sql`, #912 e evidências.
