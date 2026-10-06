# Ensaio (dry-run) do cutover — terça 06/10/2026 (D-2), cópia `postgresql-ensaio-iarandu`

Renan criou hoje (16:17 BRT) o Standard-0 temporário no app `chiefsgroup`:
addon **`postgresql-ensaio-iarandu`**, attachment **`ENSAIO_IARANDU`** (config var
`ENSAIO_IARANDU_URL`), vazio. Ele é destruído pela conta owner no fim, com o OK
da Amelia na thread. **Só a Amelia executa** o que está aqui.

Regras do ensaio:
- Tudo escreve **só na cópia**. O essential-1 (`DATABASE_URL`, `postgresql-triangular-22490`)
  é lido pelo `pg:copy` e nada mais. O Railway (`chiefs_intelligence`) é só leitura
  (o `etl.py` força a sessão READ ONLY). O dado não sai do Heroku, salvo o
  streaming do ETL Railway → Heroku, como na homolog em 19/08.
- **Cada etapa cronometrada** (`tempos.txt`): é o número que decide se as 2h cabem.
- O que o ensaio **não** cobre: `pg:promote` (não promovemos a cópia), o
  `db:migrate` do release phase do Rails (não há deploy contra a cópia) e o
  `maintenance:on/off`. Esses três são troca de config var/flag, segundos.
- Credenciais criadas na cópia morrem com o addon.
- zsh: `setopt interactivecomments` antes, ou não colar comentário na mesma linha.

## Variáveis

```bash
setopt interactivecomments
cd ~/Documents/workspace/chiefs/chiefs-db-migration
APP=chiefsgroup
CP=postgresql-ensaio-iarandu
CPVAR=ENSAIO_IARANDU
EV=evidencias/ensaio-2026-10-06; mkdir -p $EV
T() { echo "$(date -u +%FT%TZ) $*" | tee -a $EV/tempos.txt; }
url() { heroku pg:credentials:url $CP --name $1 -a $APP | grep -oE 'postgres://[^ ]+' | head -1; }
heroku pg:info DATABASE_URL -a $APP | head -3 | tee $EV/00-database-url-e-triangular.txt
heroku pg:info $CP -a $APP | tee $EV/00-pg-info-copia-antes.txt
```

A primeira saída tem de mostrar `postgresql-triangular-22490` (essential-1) e a
segunda `Tables: 0`. Se não, pare.

## 0 · O que sobrevive ao pg:copy? (pergunta do item 2)

Criar algumas roles, uma membership, um search_path e um schema **antes** da
cópia; depois dela, ver o que ficou.

```bash
for r in app_user intelligence_user tl rubi; do heroku pg:credentials:create $CP --name $r -a $APP; done
heroku pg:credentials $CP -a $APP
```

Repetir até as 4 ficarem `active`. Então:

```bash
CP_URL=$(url default)
psql "$CP_URL" -v ON_ERROR_STOP=1 -c "GRANT tl TO rubi WITH INHERIT TRUE, SET FALSE; CREATE SCHEMA sobrevive_teste; GRANT USAGE ON SCHEMA sobrevive_teste TO rubi;"
psql "$(url rubi)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-agentes.sql
cat > $EV/sobrevive.sql <<'SQL'
select 'role' tipo, rolname nome from pg_roles where rolname in ('app_user','intelligence_user','tl','rubi')
union all select 'membership', m.member::regrole::text||' em '||m.roleid::regrole::text from pg_auth_members m where m.roleid='tl'::regrole
union all select 'search_path', r.rolname||' '||s.setconfig::text from pg_db_role_setting s join pg_roles r on r.oid=s.setrole where r.rolname='rubi'
union all select 'schema', nspname from pg_namespace where nspname='sobrevive_teste'
union all select 'grant schema', 'rubi usage sobrevive_teste = '||has_schema_privilege('rubi','sobrevive_teste','USAGE')::text where exists (select 1 from pg_namespace where nspname='sobrevive_teste')
order by 1,2;
SQL
psql "$CP_URL" -f $EV/sobrevive.sql | tee $EV/00-antes-copy.txt
```

Esperado antes: 4 roles, 1 membership, 1 search_path, 1 schema, 1 grant.

## 1 · pg:copy do essential-1 para a cópia (cronometrar)

```bash
T "pg:copy inicio"
heroku pg:copy DATABASE_URL $CPVAR -a $APP
T "pg:copy fim"
heroku pg:info $CP -a $APP | tee $EV/01-pg-info-copia-depois.txt
```

O prompt de confirmação pede um nome: digite o que ele pedir (na homolog em
19/08 pediu o nome do **destino**). Esperado depois: `Tables: 99`, ~900 MB,
PG 18.6 (a origem é 17.9; é o mesmo salto do dia D).

## 2 · Depois da cópia: o que sobreviveu, extensões, inventário

```bash
psql "$CP_URL" -f $EV/sobrevive.sql | tee $EV/02-depois-copy.txt
psql "$CP_URL" -c "select extname, extversion, extnamespace::regnamespace from pg_extension order by 1" | tee $EV/02-extensoes-antes.txt
psql "$CP_URL" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public; CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;"
psql "$CP_URL" -c "select extname, extversion, extnamespace::regnamespace from pg_extension order by 1" | tee $EV/02-extensoes.txt
psql "$CP_URL" -c "select schemaname, count(*) from pg_tables where schemaname not in ('pg_catalog','information_schema') group by 1 order by 1; select tablename from pg_tables where schemaname='public' and (tablename like 'active\_campaign%' or tablename like 'ca\_%') order by 1" | tee $EV/02-inventario.txt
```

Leitura do `02-depois-copy.txt`: **roles e membership** devem continuar
(são do cluster); **schema e grant** devem ter sumido (o pg:copy zera o
banco); o **search_path** é a dúvida (configuração por banco). O que sumir
é refeito na janela, e o runbook de produção ganha a nota. As três
`active_campaign_*` e as `ca_*` precisam aparecer em `public` (insumo da
pergunta do Renan e do #912).

## 3 · P1 na cópia (schemas, roles, move para `app`, owner, USAGE)

```bash
T "P1 inicio"
for r in looker_reader analytical_reader worker jade safira ametista roma tokyo bogota oslo raiz grass ocean white n8n_contexto_cliente n8n_fila_salesops; do heroku pg:credentials:create $CP --name $r -a $APP; done
heroku pg:credentials $CP -a $APP | tee $EV/03-credenciais.txt
```

Repetir até 21 `active` (20 + default). Depois, o SQL do P1 como default.
A seção 8 (search_path do `app_user`) pode dar `permission denied to alter
role` no fim, depois de tudo commitado; aí roda como o próprio `app_user`:

```bash
psql "$CP_URL" -v ON_ERROR_STOP=1 -f "../p1/2.schemas-roles-grants.sql" 2>&1 | tee $EV/03-p1-grants.txt
psql "$(url app_user)" -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN EXECUTE format('ALTER ROLE app_user IN DATABASE %I SET search_path = app, public, heroku_ext', current_database()); END \$\$;" 2>&1 | tee $EV/03-search-path-app-user.txt
psql "$CP_URL" -c "select schemaname, count(*) from pg_tables where schemaname in ('public','app') group by 1; select tablename from pg_tables where schemaname='app' and tablename like 'active\_campaign%' order by 1" | tee $EV/03-move-app.txt
psql "$CP_URL" -c "select r.rolname, has_database_privilege(r.rolname, current_database(), 'CONNECT') as connect from pg_roles r where r.rolname in ('app_user','intelligence_user','looker_reader','analytical_reader','tl','worker','rubi','jade','safira','ametista','roma','tokyo','bogota','oslo','raiz','grass','ocean','white','n8n_contexto_cliente','n8n_fila_salesops') order by 1" | tee $EV/03-connect.txt
```

Esperado: 99 tabelas em `app`, 0 em `public`, as 3 `active_campaign_*` em
`app` (**resposta ao Renan: o move é a seção 7 do P1, um loop sobre todas as
tabelas de `public`, e roda antes do alembic**). `connect = t` para as 20.
Se alguma vier `f` (o P1 revoga CONNECT de PUBLIC e só devolve às 4 roles
dele), conceder e anotar para o runbook da janela:

```bash
psql "$CP_URL" -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN EXECUTE format('GRANT CONNECT ON DATABASE %I TO tl, worker, rubi, jade, safira, ametista, roma, tokyo, bogota, oslo, raiz, grass, ocean, white, n8n_contexto_cliente, n8n_fila_salesops', current_database()); END \$\$;"
```

Owner e USAGE (idempotentes; o P1 ≥ 10/09 já faz, mas são a garantia):

```bash
psql "$CP_URL" -v ON_ERROR_STOP=1 -f ddl/p2-owner-app.sql 2>&1 | tee $EV/03-owner-app.txt
psql "$CP_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-public-usage.sql 2>&1 | tee $EV/03-public-usage.txt
T "P1 fim"
```

## 4 · DDL do enriquecimento e do schema `intelligence`

```bash
T "DDL inicio"
psql "$CP_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-main-enrichment.sql 2>&1 | tee $EV/04-enrichment.txt
psql "$CP_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-intelligence-schema.sql 2>&1 | tee $EV/04-ddl-intelligence.txt
T "DDL fim"
```

## 5 · ETL contra o Railway de produção (só leitura na origem)

Origem: bloco "Intelligence" do `notes.txt` (host `interchange.proxy.rlwy.net`,
porta 21225, db `chiefs_intelligence`, user `postgres`; o proxy do Railway não
tem SSL → `prefer`). Destino: a credencial default da cópia.

```bash
export SRC_HOST=interchange.proxy.rlwy.net SRC_PORT=21225 SRC_DB=chiefs_intelligence SRC_USER=postgres SRC_SSLMODE=prefer
export SRC_PASSWORD='<senha do bloco Intelligence do notes.txt>'
export DST_HOST=$(sed -E 's#postgres://[^@]+@([^:]+):.*#\1#' <<<"$CP_URL") DST_PORT=5432
export DST_DB=$(sed -E 's#.*/##' <<<"$CP_URL") DST_USER=$(sed -E 's#postgres://([^:]+):.*#\1#' <<<"$CP_URL")
export DST_PASSWORD=$(sed -E 's#postgres://[^:]+:([^@]+)@.*#\1#' <<<"$CP_URL") DST_SSLMODE=require APP_SCHEMA=app
echo "$DST_HOST $DST_DB $DST_USER"
T "validate-only inicio"; python3 etl/etl.py --validate-only 2>&1 | tee $EV/05-validate-only-antes.txt; T "validate-only fim"
```

O `--validate-only` antes da carga mostra divergência de contagem (destino
vazio), o que não importa; o que importa é **nenhuma linha de DRIFT** no
re-diff de colunas. Drift = parar, ajustar o DDL, seguir. Depois:

```bash
T "ETL inicio"; python3 etl/etl.py --merge 2>&1 | tee $EV/05-etl-merge.txt; T "ETL fim"
psql "$CP_URL" -v app_schema=app -f etl/04-integridade.sql 2>&1 | tee $EV/05-integridade.txt
psql "$CP_URL" -c "select version_num from intelligence.alembic_version; select indexname from pg_indexes where schemaname='intelligence' and indexdef ilike '%hnsw%'" | tee $EV/05-alembic-hnsw.txt
```

Esperado: `== ZERO DIVERGÊNCIAS ==`, merge com `divergentes=0`,
`alembic_version` semeada em `106_job_descriptions_outcome`, `owner →
intelligence_user`, `ANALYZE`, `INTEGRIDADE: OK`, 3 índices HNSW. O tempo
do ETL já inclui a construção dos HNSW (os índices existem antes da carga).
Referência da homolog: ~3 min.

## 6 · Grants do `intelligence_user` (#912) antes do alembic

```bash
T "grants-912 inicio"
psql "$CP_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-intelligence-user-minimo.sql 2>&1 | tee $EV/06-912.txt
psql "$(url intelligence_user)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-intelligence-user.sql 2>&1 | tee $EV/06-search-path-intelligence-user.txt
T "grants-912 fim"
```

Esperado como na homolog: 3 linhas table-level (`active_campaign_*`), 24
tabelas por coluna, 53 UPDATE em `app.chiefs`. Se o arquivo abortar por
tabela/coluna ausente em produção, nada foi aplicado (transação única):
anotar a diferença, é achado do ensaio, e seguir sem o #912 (o alembic roda
com o SELECT amplo do P1).

## 7 · Chiefs: `alembic upgrade head` e smoke do Intelligence na cópia

Avisar na thread: credencial **`intelligence_user`** da cópia
(`heroku pg:credentials:url postgresql-ensaio-iarandu --name intelligence_user -a chiefsgroup`).
Eles apontam o service de teste, rodam 106 → 116 e o smoke, e postam o tempo.

```bash
T "alembic (Chiefs) inicio"
# ... aguardar a confirmação deles na thread ...
T "alembic (Chiefs) fim"
psql "$CP_URL" -c "select version_num from intelligence.alembic_version; select relname, relkind, pg_get_userbyid(relowner) from pg_class where relnamespace='intelligence'::regnamespace and relname in ('chiefs_ativos','chiefs_todos','pipedrive_deals','ac_contacts','ac_campaigns','ac_contact_messages','compat_array_text') order by 1" | tee $EV/07-pos-alembic.txt
```

Esperado: `116`, views `chiefs_ativos`/`chiefs_todos`/`pipedrive_deals`/`ac_*`
com owner `intelligence_user`. **Se as `ac_*` não existirem**, a migration 114
passou em silêncio: significa que as `active_campaign_*` não estavam em `app`
(conferir o `03-move-app.txt`).

## 8 · Índices de `app.chiefs` (default; sem CONCURRENTLY, como na janela)

```bash
T "indices inicio"
sed 's/ CONCURRENTLY//' ddl/ddl-main-enrichment-indexes.sql | psql "$CP_URL" -v ON_ERROR_STOP=1 -f - 2>&1 | tee $EV/08-indices.txt
T "indices fim"
```

## 9 · Grants que dependem das views (agentes, n8n) e testes

```bash
T "grants-agentes-n8n inicio"
psql "$CP_URL" -v ON_ERROR_STOP=1 -v ambiente=producao -f ddl/p2-roles-agentes.sql 2>&1 | tee $EV/09-roles-agentes.txt
for u in rubi jade safira ametista roma tokyo bogota oslo raiz grass ocean white n8n_contexto_cliente n8n_fila_salesops; do psql "$(url $u)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-agentes.sql; done 2>&1 | tee $EV/09-search-path-agentes.txt
psql "$CP_URL" -v ON_ERROR_STOP=1 -f ddl/p2-roles-n8n.sql 2>&1 | tee $EV/09-roles-n8n.txt
T "grants-agentes-n8n fim"
APP=$APP DB=$CP AMBIENTE=producao bash scripts/testa-permissoes-agentes.sh | tee $EV/09-teste-agentes.txt
APP=$APP DB=$CP bash scripts/testa-permissoes-n8n.sh | tee $EV/09-teste-n8n.txt
```

Esperado: `p2-roles-agentes.sql` com 12 memberships (os 4 do Duda em
`worker`), escrita só do `tl` (7 linhas), 21 tabelas/340 colunas por grupo;
teste dos agentes **`360 PASS, 0 FAIL`** (12 usuários; antes do Duda eram 240);
n8n **`45 PASS, 0 FAIL`**.

## 10 · Smoke por conteúdo

```bash
psql "$CP_URL" -c "select 'ac_contacts' v, count(*) from intelligence.ac_contacts union all select 'ac_campaigns', count(*) from intelligence.ac_campaigns union all select 'ac_contact_messages', count(*) from intelligence.ac_contact_messages union all select 'chiefs_ativos', count(*) from intelligence.chiefs_ativos union all select 'pipedrive_deals', count(*) from intelligence.pipedrive_deals" | tee $EV/10-smoke-views.txt
psql "$(url intelligence_user)" -c "explain (analyze, buffers) select id from chief_embeddings order by embedding <=> (select embedding from chief_embeddings where embedding is not null limit 1) limit 10" | tee $EV/10-smoke-hnsw.txt
psql "$CP_URL" -c "select usename, application_name, count(*) from pg_stat_activity where datname = current_database() group by 1, 2 order by 1, 2" | tee $EV/10-conexoes.txt
heroku pg:info DATABASE_URL -a $APP | tee $EV/10-essential1-intocado.txt
```

Referência das `ac_*`: 7.091 / 354 / 36.951 na leitura de hoje em produção
(a cópia é de agora, pode ter mais). O plano do HNSW tem de usar
`Index Scan using ix_chief_embeddings_hnsw_cosine`. O essential-1 tem de
estar igual ao `00-database-url-e-triangular.txt`.

## 11 · Rollback (perna do banco) e encerramento

Na janela o rollback é `heroku pg:promote HEROKU_POSTGRESQL_RED_URL -a chiefsgroup`
(troca de config var, segundos) mais o Intelligence de volta ao Railway
(Chiefs). Na cópia não há promoção a desfazer; o que se comprova é que as
duas origens ficaram intocadas (o `10-essential1-intocado.txt` e a sessão
READ ONLY do ETL) e que a Chiefs consegue repontar o service de teste de
volta ao Railway, cronometrado por eles.

```bash
T "ensaio fim"
column -t $EV/tempos.txt | tee $EV/11-resumo-tempos.txt
```

Fechamento, na thread: tempos por etapa e se cabe nas 2h (meta ≤ 1h30);
achados (o que sobreviveu ao pg:copy, CONNECT, #912 em produção, `ac_*`);
**OK para o Renan destruir o `postgresql-ensaio-iarandu`**. Depois: registrar
em `p3/0. p3-entregas.md` e commitar as evidências (sem URL nem senha).

## Orçamento das 2h (preencher com o medido)

| Etapa | Medido | Quem |
|---|---|---|
| pg:copy essential-1 → Standard-0 (902 MB) | | Amelia |
| P1 (credenciais, grants, move, owner, USAGE) | | Amelia |
| DDL enrichment + intelligence | | Amelia |
| ETL (49 tabelas + merge + HNSW + ANALYZE) | | Amelia |
| #912 + search_path | | Amelia |
| alembic 106 → 116 + smoke | | Chiefs |
| índices app.chiefs | | Amelia |
| grants agentes/n8n + testes | | Amelia |
| smoke por conteúdo | | Amelia |
| pg:promote + maintenance (não ensaiado) | ~1 min | Renan/Amelia |
