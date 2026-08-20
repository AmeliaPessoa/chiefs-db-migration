#!/usr/bin/env bash
# P2 ETL · Validação local em Docker (Postgres 17 + pgvector) — §5.1-compliant
#
# MODO PADRÃO (sintético): schema-only + dados sintéticos gerados aqui —
# NENHUM dado real toca a máquina local (alinhado ao feedback de 20/08,
# pendência 6). Exercita: carga das 48, merge das híbridas (conflito
# ativos×todos, ids sem match), sequences, view e validações.
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
-- carga das 48: algumas tabelas simples com linhas
INSERT INTO public.alembic_version (version_num) VALUES ('sintetico_0001');
INSERT INTO public.platform_sync_state ("key", last_sync_at, last_full_sync_at)
VALUES ('sintetico', now(), now());
SQL

  echo "==> [2c/8] Seed sintético no DESTINO (main schema-only)"
  psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 <<'SQL'
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

echo "==> [4/8] DDL do schema intelligence (48 tabelas + view) — view repontada para public local"
sed 's/app\.pipedrive_deals/public.pipedrive_deals/' "$DIR/../ddl/ddl-intelligence-schema.sql" \
  | psql_c -d $MAIN_DB -v ON_ERROR_STOP=1

echo "==> [5/8] FDW → carga das 48"
docker exec -i -e PGPASSWORD=etl-local $CT psql -U postgres -q -d $MAIN_DB \
  -v src_host=localhost -v src_port=5432 -v src_db=$INTEL_DB \
  -v src_user=postgres -v src_pass=etl-local \
  -f - < "$DIR/00-fdw-setup.sql"
psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 < "$DIR/01-load-intelligence.sql"

echo "==> [6/8] Merge das híbridas"
psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 -v app_schema=public < "$DIR/02-merge-main.sql" \
  | tee /tmp/etl-merge-report.txt

echo "==> [7/8] Validação das contagens (48 tabelas)"
psql_c -d $MAIN_DB < "$DIR/03-validate.sql" | tee /tmp/etl-validation-report.txt

echo "==> [8/8] Integridade (sequences + FKs lógicas)"
psql_c -d $MAIN_DB -v app_schema=public < "$DIR/04-integridade.sql" | tail -8

echo
echo "Relatórios: /tmp/etl-validation-report.txt e /tmp/etl-merge-report.txt"
echo "Container '$CT' fica no ar: psql -h localhost -p $PORT -U postgres -d $MAIN_DB"
echo "Para derrubar: docker rm -f $CT"
