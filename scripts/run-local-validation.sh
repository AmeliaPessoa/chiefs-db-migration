#!/usr/bin/env bash
# P2 ETL · Validação local da carga em Docker (Postgres 17 + pgvector)
# Sobe um container, carrega os dois dumps, aplica os DDLs do P2 e roda o ETL
# completo (carga das 48 + merge das híbridas) com relatório de validação.
# Nada toca as bases reais.
#
# Vereditos 13/08: 48 tabelas no schema `intelligence`; enriquecimento entra
# no main via ALTER + UPDATE (chiefs +53, pipedrive_deals +4).
# Ajuste local: no dump da main as tabelas vivem em `public` (não em `app`),
# então o enrichment/merge/view são aplicados com schema `public` via sed/-v.
#
# Uso:  bash p2/etl/run-local-validation.sh          (a partir da raiz do workspace)
set -euo pipefail

DIR="$(cd "$(dirname "$0")/../etl" && pwd)"   # etl/ do repo
ROOT="$(cd "$DIR/../.." && pwd)"              # raiz do workspace
# dumps NÃO ficam no repositório (dado real não sai do ambiente — §5.1):
# aponte para os arquivos locais via variáveis de ambiente.
DUMP_INTEL="${DUMP_INTEL:?defina DUMP_INTEL=<caminho do dump da intelligence>}"
DUMP_MAIN="${DUMP_MAIN:-}"                     # opcional
DDL_MAIN_SCHEMA_ONLY="${DDL_MAIN_SCHEMA_ONLY:-}"  # fallback se o dump da main faltar
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

# os dumps foram gerados com --create: eles criam e conectam nos bancos originais
MAIN_DB=dcq9d97tueu0oq
INTEL_DB=chiefs_intelligence

echo "==> [2/8] Criando roles referenciadas pelos dumps"
psql_c -c "CREATE ROLE u8gp82m14h2tkk;" || true
psql_c -c "CREATE ROLE chiefs_ro;" || true

echo "==> [3/8] Carregando dump da intelligence (~1.0 GB — alguns minutos, cria o banco $INTEL_DB)"
if [ -f "$DUMP_INTEL" ]; then
  docker exec -i -e PGPASSWORD=etl-local -e PGOPTIONS="-c synchronous_commit=off" \
    $CT psql -U postgres -q -d postgres < "$DUMP_INTEL" 2> /tmp/load-intel.err || true
  echo "    erros ignorados: $(grep -c ERROR /tmp/load-intel.err || true) (ver /tmp/load-intel.err)"
else
  echo "    ERRO: dump da origem não encontrado ($DUMP_INTEL)."
  echo "    Sem origem não há o que validar — aponte DUMP_INTEL para um dump"
  echo "    (idealmente schema-only + subset sintético, conforme §5.1) ou use"
  echo "    o FDW direto contra uma origem de teste."
  exit 1
fi

echo "==> [4/8] Preparando o banco de destino"
if [ -f "$DUMP_MAIN" ]; then
  docker exec -i -e PGPASSWORD=etl-local -e PGOPTIONS="-c synchronous_commit=off" \
    $CT psql -U postgres -q -d postgres < "$DUMP_MAIN" 2> /tmp/load-main.err || true
  echo "    erros ignorados: $(grep -c ERROR /tmp/load-main.err || true) (ver /tmp/load-main.err)"
else
  # sem dump da main: destino com o DDL schema-only (merge atualizará 0 linhas)
  MAIN_DB=destino
  echo "    dump da main ausente — criando '$MAIN_DB' com o schema-only ($DDL_MAIN_SCHEMA_ONLY)"
  psql_c -c "DROP DATABASE IF EXISTS $MAIN_DB;" -c "CREATE DATABASE $MAIN_DB;"
  psql_c -d $MAIN_DB < "$DDL_MAIN_SCHEMA_ONLY" 2>/dev/null || true
fi

echo "==> [5/8] Enriquecimento do main (chiefs +53, pipedrive_deals +4) — schema public local"
sed 's/SET search_path = app;/SET search_path = public;/' "$DIR/../ddl/ddl-main-enrichment.sql" \
  | psql_c -d $MAIN_DB -v ON_ERROR_STOP=1

echo "==> [6/8] DDL do schema intelligence (48 tabelas + view) — view repontada para public local"
sed 's/app\.pipedrive_deals/public.pipedrive_deals/' "$DIR/../ddl/ddl-intelligence-schema.sql" \
  | psql_c -d $MAIN_DB -v ON_ERROR_STOP=1

echo "==> [7/8] ETL: FDW → carga das 48 + merge das híbridas"
docker exec -i -e PGPASSWORD=etl-local $CT psql -U postgres -q -d $MAIN_DB \
  -v src_host=localhost -v src_port=5432 -v src_db=$INTEL_DB \
  -v src_user=postgres -v src_pass=etl-local \
  -f - < "$DIR/00-fdw-setup.sql"
psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 < "$DIR/01-load-intelligence.sql"
psql_c -d $MAIN_DB -v ON_ERROR_STOP=1 -v app_schema=public < "$DIR/02-merge-main.sql" \
  | tee /tmp/etl-merge-report.txt

echo "==> [8/8] Validação das contagens (48 tabelas)"
psql_c -d $MAIN_DB < "$DIR/03-validate.sql" | tee /tmp/etl-validation-report.txt

echo
echo "Relatórios: /tmp/etl-validation-report.txt (contagens) e /tmp/etl-merge-report.txt (merge)"
echo "Container '$CT' fica no ar para inspeção: psql -h localhost -p $PORT -U postgres -d $MAIN_DB"
echo "Para derrubar: docker rm -f $CT"
