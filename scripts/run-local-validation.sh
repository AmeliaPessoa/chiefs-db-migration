#!/usr/bin/env bash
# P2 ETL · Validação local em Docker (Postgres 17 + pgvector) — §5.1-compliant
#
# MODO PADRÃO (sintético): schema-only + dados sintéticos gerados aqui —
# NENHUM dado real toca a máquina local (alinhado ao feedback de 20/08,
# pendência 6). Exercita: carga das 49, merge das híbridas (conflito
# ativos×todos, ids sem match), sequences, view e validações — e, no passo 9,
# a RE-EXECUÇÃO D-1 com o etl.py no cenário do feedback de 08/09: objetos
# criados pelo Intelligence no schema (view, tabela, coluna, alembic_version)
# precisam sobreviver, e o owner final precisa ser intelligence_user.
#
# MODO LEGADO (dumps reais): USE_REAL_DUMPS=1 + DUMP_INTEL=... [DUMP_MAIN=...]
# — usar SOMENTE em ambiente autorizado pela Chiefs (§5.1).
#
# Uso:  bash scripts/run-local-validation.sh          (a partir da raiz)
set -euo pipefail

DIR="$(cd "$(dirname "$0")/../etl" && pwd)"   # etl/ do repo
ROOT="$(cd "$DIR/.." && pwd)"                 # raiz do repo
SCHEMA_INTEL="${SCHEMA_INTEL:-$ROOT/ddl/intelligence-origin-schema.sql}"   # schema-only da origem
SCHEMA_MAIN="${SCHEMA_MAIN:-$ROOT/ddl/main-schema-snapshot.sql}"             # schema-only do main
CT=chiefs-etl-validate
PORT="${ETL_PG_PORT:-5599}"
export PGPASSWORD=etl-local

psql_c() { docker exec -i -e PGPASSWORD=etl-local -e PGOPTIONS="-c synchronous_commit=off" $CT psql -U postgres -q "$@"; }

echo "==> [1/8] Subindo container ($CT, porta $PORT)"
docker rm -f $CT >/dev/null 2>&1 || true
docker run -d --name $CT -e POSTGRES_PASSWORD=etl-local -p $PORT:5432 \
  pgvector/pgvector:pg17 >/dev/null
until docker exec $CT pg_isready -U postgres -q 2>/dev/null; do sleep 1; done
sleep 2

INTEL_DB=chiefs_intelligence
MAIN_DB=destino

if [ "${USE_REAL_DUMPS:-0}" = "1" ]; then
  echo "==> [2/8] MODO LEGADO: carregando dumps reais (⚠ só em ambiente autorizado — §5.1)"
  : "${DUMP_INTEL:?USE_REAL_DUMPS=1 exige DUMP_INTEL=<dump da intelligence>}"
  psql_c -c "CREATE ROLE u8gp82m14h2tkk;" 2>/dev/null || true
  psql_c -c "CREATE ROLE chiefs_ro;" 2>/dev/null || true
  docker exec -i -e PGPASSWORD=etl-local $CT psql -U postgres -q -d postgres < "$DUMP_INTEL" 2>/tmp/load-intel.err || true
  if [ -n "${DUMP_MAIN:-}" ]; then
    docker exec -i -e PGPASSWORD=etl-local $CT psql -U postgres -q -d postgres < "$DUMP_MAIN" 2>/tmp/load-main.err || true
    MAIN_DB=dcq9d97tueu0oq
  else
    psql_c -c "CREATE DATABASE $MAIN_DB;"
    psql_c -d $MAIN_DB < "$SCHEMA_MAIN" 2>/dev/null || true
  fi
else
  echo "==> [2/8] MODO SINTÉTICO: origem/destino de schema-only + seed sintético"
  psql_c -c "CREATE DATABASE $INTEL_DB;" -c "CREATE DATABASE $MAIN_DB;"
  psql_c -d $INTEL_DB < "$SCHEMA_INTEL" 2>/tmp/schema-intel.err || true
  psql_c -d $MAIN_DB  < "$SCHEMA_MAIN"  2>/tmp/schema-main.err  || true

  echo "==> [2b/8] Seed sintético na ORIGEM (nenhum dado real)"
  psql_c -d $INTEL_DB -v ON_ERROR_STOP=1 <<'SQL'
-- merge sources: 101 = nos dois (ativos vence), 102 = só ativos,
-- 103 = só todos, 104 = sem match no main (descartado)
INSERT INTO public.chiefs_ativos (id, name, email, enrichment_status, iqp_score, attractiveness_score, resume_combined)
VALUES ('101','Chief Sintético Um','c101@teste.local','done',88.5,7.1,'cv sintético 101'),
       ('102','Chief Sintético Dois','c102@teste.local','done',72.0,5.5,'cv sintético 102'),
       ('104','Chief Sem Match','c104@teste.local','pending',NULL,NULL,NULL);
INSERT INTO public.chiefs_todos (id, name, email, enrichment_status, iqp_score, resume_combined)
VALUES ('101','Chief Sintético Um','c101@teste.local','stale',10.0,'NÃO DEVE VENCER'),
       ('103','Chief Sintético Três','c103@teste.local','done',60.3,'cv sintético 103');
INSERT INTO public.pipedrive_deals (id, title, notes, files, origem_oportunidade, utm_source)
VALUES (9001,'Deal Sintético A','[{"nota":"a"}]'::jsonb,'[]'::jsonb,'{"origem":"evento"}'::jsonb,'linkedin'),
       (9002,'Deal Sintético B','[]'::jsonb,'[]'::jsonb,NULL,NULL),
       (9999,'Deal Sem Match','[{"nota":"x"}]'::jsonb,'[]'::jsonb,NULL,'ads');
-- carga das 49: algumas tabelas simples com linhas
INSERT INTO public.alembic_version (version_num) VALUES ('sintetico_0001');
INSERT INTO public.platform_sync_state ("key", last_sync_at, last_full_sync_at)
VALUES ('sintetico', now(), now());
INSERT INTO public.chief_perfil_perguntas (chief_id, perguntas) VALUES (101, '["pergunta sintética"]'::jsonb);
INSERT INTO public.job_descriptions (id, title, is_test, outcome, dados_base_extraidos)
VALUES (7001, 'JD sintética', true, 'contratado', '{"cargo":"CFO sintético"}'::jsonb);
INSERT INTO public.jd_external_candidates (jd_id, candidate_name, candidate_email)
VALUES (7001, 'Candidato Sintético', 'cand@teste.local');
-- (o snapshot da origem já traz os backups chief_embeddings_bak_20260803 e
--  chiefs_reenrich_backup_20260831 — o ETL deve só AVISAR e descartá-los)
SQL

  echo "==> [2c/8] Seed sintético no DESTINO (main schema-only) + role intelligence_user"
  psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE intelligence_user NOLOGIN;
INSERT INTO public.chiefs (id, name, email, created_at, updated_at)
VALUES (101,'Chief Sintético Um','c101@teste.local',now(),now()),
       (102,'Chief Sintético Dois','c102@teste.local',now(),now()),
       (103,'Chief Sintético Três','c103@teste.local',now(),now());
INSERT INTO public.pipedrive_deals (id, pipedrive_id, title, created_at, updated_at)
VALUES (1,9001,'Deal Sintético A',now(),now()),
       (2,9002,'Deal Sintético B',now(),now());
SQL
fi

echo "==> [3/8] Enriquecimento do main (chiefs +53, pipedrive_deals +4) — schema public local"
sed 's/SET search_path = app;/SET search_path = public;/' "$DIR/../ddl/ddl-main-enrichment.sql" \
  | psql_c -d $MAIN_DB -v ON_ERROR_STOP=1

echo "==> [4/8] DDL do schema intelligence (49 tabelas + alembic_version + view) — view repontada para public local"
sed 's/app\.pipedrive_deals/public.pipedrive_deals/' "$DIR/../ddl/ddl-intelligence-schema.sql" \
  | psql_c -d $MAIN_DB -v ON_ERROR_STOP=1
# grants + default privileges como no P1 (para provar no passo 9 que sobrevivem)
psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 -c "GRANT USAGE, CREATE ON SCHEMA intelligence TO intelligence_user;" \
  -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA intelligence TO intelligence_user;" \
  -c "ALTER DEFAULT PRIVILEGES IN SCHEMA intelligence GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO intelligence_user;"

echo "==> [5/8] FDW → carga das 49"
docker exec -i -e PGPASSWORD=etl-local $CT psql -U postgres -q -d $MAIN_DB \
  -v src_host=localhost -v src_port=5432 -v src_db=$INTEL_DB \
  -v src_user=postgres -v src_pass=etl-local \
  -f - < "$DIR/00-fdw-setup.sql"
psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 < "$DIR/01-load-intelligence.sql"
# 1ª carga semeia a versão fixa 106 (24/09, opção b), não a da origem ('sintetico_0001')
[ "$(psql_c -d $MAIN_DB -At -c "SELECT string_agg(version_num, ',') FROM intelligence.alembic_version")" = "106_job_descriptions_outcome" ] \
  || { echo "FALHA: alembic_version não foi semeada com 106_job_descriptions_outcome"; exit 1; }
echo "   alembic_version semeada: 106_job_descriptions_outcome"

echo "==> [6/8] Merge das híbridas"
psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 -v app_schema=public < "$DIR/02-merge-main.sql" \
  | tee /tmp/etl-merge-report.txt

echo "==> [7/8] Validação das contagens (49 tabelas)"
psql_c -d $MAIN_DB < "$DIR/03-validate.sql" | tee /tmp/etl-validation-report.txt

echo "==> [8/8] Integridade (sequences + FKs lógicas)"
psql_c -d $MAIN_DB -v app_schema=public < "$DIR/04-integridade.sql" | tail -8

echo "==> [9] Re-execução D-1 com etl.py — cenário do feedback 08/09 (objetos do Intelligence no schema)"
if python3 -c 'import psycopg2' 2>/dev/null; then
  # o que o Intelligence cria no destino durante o teste (migrations 104→107):
  psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 <<'SQL'
CREATE VIEW intelligence.chiefs_todos AS SELECT id::text AS id, name, enrichment_status FROM public.chiefs;
CREATE TABLE intelligence.tabela_do_cliente (id bigserial PRIMARY KEY, x text);
INSERT INTO intelligence.tabela_do_cliente (x) VALUES ('linha 1'), ('linha 2');
ALTER TABLE intelligence.jd_results ADD COLUMN coluna_so_no_destino text DEFAULT 'default-ok';
UPDATE intelligence.alembic_version SET version_num = '107_cliente';
ALTER TABLE intelligence.tabela_do_cliente OWNER TO intelligence_user;
SQL
  # guarda (24/09): nome de view de compat existindo como TABELA tem de barrar a carga
  psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 -c "CREATE TABLE intelligence.ac_contacts (id bigint);"
  if SRC_HOST=localhost SRC_PORT=$PORT SRC_DB=$INTEL_DB SRC_USER=postgres SRC_PASSWORD=etl-local \
     DST_HOST=localhost DST_PORT=$PORT DST_DB=$MAIN_DB DST_USER=postgres DST_PASSWORD=etl-local \
     APP_SCHEMA=public DST_OBJECT_OWNER=intelligence_user \
     python3 "$DIR/etl.py" --merge > /tmp/etl-guard-compat.txt 2>&1; then
    echo "FALHA: etl.py não barrou intelligence.ac_contacts como tabela"; exit 1
  fi
  grep -q "existem como TABELA: \['ac_contacts'\]" /tmp/etl-guard-compat.txt \
    || { echo "FALHA: etl.py falhou por outro motivo:"; tail -5 /tmp/etl-guard-compat.txt; exit 1; }
  psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 -c "DROP TABLE intelligence.ac_contacts;"
  echo "   guarda das views de compat: OK (carga barrada, nada escrito)"

  SRC_HOST=localhost SRC_PORT=$PORT SRC_DB=$INTEL_DB SRC_USER=postgres SRC_PASSWORD=etl-local \
  DST_HOST=localhost DST_PORT=$PORT DST_DB=$MAIN_DB DST_USER=postgres DST_PASSWORD=etl-local \
  APP_SCHEMA=public DST_OBJECT_OWNER=intelligence_user \
  python3 "$DIR/etl.py" --merge | tee /tmp/etl-rerun-d1.txt
  grep -q '== ZERO DIVERGÊNCIAS ==' /tmp/etl-rerun-d1.txt || { echo "FALHA: etl.py divergiu"; exit 1; }
  grep -q 'ANALYZE em 51 tabela(s)' /tmp/etl-rerun-d1.txt || { echo "FALHA: etl.py não fez ANALYZE (49 + 2 híbridas)"; exit 1; }
  psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 -At <<'SQL' | tee /tmp/etl-rerun-d1-check.txt
SELECT 'view chiefs_todos preservada: '||(SELECT count(*) FROM pg_views WHERE schemaname='intelligence' AND viewname='chiefs_todos');
SELECT 'tabela do cliente preservada (linhas): '||(SELECT count(*) FROM intelligence.tabela_do_cliente);
SELECT 'coluna só no destino preservada: '||(SELECT count(*) FROM information_schema.columns WHERE table_schema='intelligence' AND table_name='jd_results' AND column_name='coluna_so_no_destino');
SELECT 'alembic_version preservada: '||(SELECT string_agg(version_num, ',') FROM intelligence.alembic_version);
SELECT 'owner intelligence_user (tabelas/seqs/views): '||(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='intelligence' AND c.relkind IN ('r','S','v') AND c.relowner='intelligence_user'::regrole)||' de '||(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='intelligence' AND c.relkind IN ('r','S','v'));
SELECT 'grant SELECT intelligence_user em jd_results: '||has_table_privilege('intelligence_user','intelligence.jd_results','SELECT');
SELECT 'default privileges no schema: '||(SELECT count(*) FROM pg_default_acl WHERE defaclnamespace='intelligence'::regnamespace);
SELECT 'chief_perfil_perguntas carregada: '||(SELECT count(*) FROM intelligence.chief_perfil_perguntas);
SELECT 'job_descriptions.is_test/outcome carregados: '||(SELECT count(*) FROM intelligence.job_descriptions WHERE is_test AND outcome='contratado');
SELECT 'job_descriptions.dados_base_extraidos carregado: '||(SELECT count(*) FROM intelligence.job_descriptions WHERE dados_base_extraidos->>'cargo' = 'CFO sintético');
SELECT 'jd_external_candidates carregada: '||(SELECT count(*) FROM intelligence.jd_external_candidates);
SQL
  psql_c -d $MAIN_DB -At -c "SELECT CASE WHEN (SELECT count(*) FROM intelligence.tabela_do_cliente)=2 AND (SELECT string_agg(version_num,',') FROM intelligence.alembic_version)='107_cliente' AND EXISTS (SELECT 1 FROM pg_views WHERE schemaname='intelligence' AND viewname='chiefs_todos') AND NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='intelligence' AND c.relkind IN ('r','S','v') AND c.relowner<>'intelligence_user'::regrole) THEN 'CENÁRIO D-1: OK' ELSE 'CENÁRIO D-1: FALHOU' END" | tee -a /tmp/etl-rerun-d1-check.txt
else
  echo "   (psycopg2 ausente — passo 9 pulado; pip3 install psycopg2-binary)"
fi

echo
echo "Relatórios: /tmp/etl-validation-report.txt e /tmp/etl-merge-report.txt"
echo "Container '$CT' fica no ar: psql -h localhost -p $PORT -U postgres -d $MAIN_DB"
echo "Para derrubar: docker rm -f $CT"
