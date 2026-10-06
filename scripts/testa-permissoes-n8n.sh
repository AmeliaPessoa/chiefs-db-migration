#!/usr/bin/env bash
# P2/P3 · Teste permitido/negado das credenciais do n8n (ddl/p2-roles-n8n.sql)
#
# Mesmo padrão do testa-permissoes-agentes.sh: conecta como CADA credencial
# (heroku pg:credentials:url) e roda cada comando em BEGIN … ROLLBACK, com
# WHERE false / INSERT … SELECT … WHERE false — o Postgres checa o privilégio
# de todas as colunas referenciadas (INSERT, SET, WHERE, RETURNING, ON CONFLICT)
# sem tocar linha nenhuma. Os comandos "ok" reproduzem o SQL real dos nodes
# auditados pelo Duda na instância de PROD do n8n (05/10), SEM schema (dependem
# do search_path da role).
#
# Uso (a partir da raiz do repo):
#   APP=chiefsgroup-homolog bash scripts/testa-permissoes-n8n.sh \
#     | tee evidencias/feedback-2026-10-05/NN-permissoes-n8n-homolog.txt
#   (produção: APP=chiefsgroup DB=<addon>; mesmos grants, mesmo resultado esperado)
# mql_candidates: por padrão CENÁRIO B (06/10) — nenhum privilégio para o n8n → as
# sondas do nó "Persist MQL Candidate" esperam "negado". MQL_CANDIDATES=A inverte
# (depois de ddl/p2-roles-n8n-mql-candidates.sql).
# Alternativa sem Heroku (validação local): URL_n8n_contexto_cliente=postgres://... URL_n8n_fila_salesops=postgres://...
set -uo pipefail

DB="${DB:-DATABASE_URL}"
CACHE="$(mktemp -d)"; trap 'rm -rf "$CACHE"' EXIT
pass=0; fail=0

url_de() {
  local v="URL_$1"
  if [[ -n "${!v:-}" ]]; then echo "${!v}"; return; fi
  : "${APP:?defina APP=<app-heroku> (ou URL_<credencial>=postgres://...)}"
  [[ -s "$CACHE/$1" ]] || heroku pg:credentials:url "$DB" --name "$1" -a "$APP" | grep -oE 'postgres://[^ ]+' | head -1 > "$CACHE/$1"
  cat "$CACHE/$1"
}

# t <credencial> <ok|negado> <sql>
t() {
  local u="$1" esperado="$2" sql="$3" out obtido
  out="$(psql "$(url_de "$u")" -X -q -v ON_ERROR_STOP=1 -c "BEGIN; $sql; ROLLBACK;" 2>&1)"
  if [[ $? -eq 0 ]]; then obtido=ok
  elif grep -q "permission denied\|must be owner" <<<"$out"; then obtido=negado
  else obtido="ERRO: $(head -1 <<<"$out")"; fi
  if [[ "$obtido" == "$esperado" ]]; then ((pass++)); printf 'PASS  %-21s %-7s %s\n' "$u" "$esperado" "${sql:0:110}"
  else ((fail++)); printf 'FAIL  %-21s esperado=%s obtido=%s  %s\n' "$u" "$esperado" "$obtido" "${sql:0:110}"; fi
}

MQL="${MQL_CANDIDATES:-B}"
if [[ "$MQL" == A ]]; then MQL_OK=ok; else MQL_OK=negado; fi

SEARCH_PATH_OK="DO \$\$ BEGIN IF current_setting('search_path') !~ '^intelligence' THEN RAISE 'search_path errado: %', current_setting('search_path'); END IF; END \$\$"

echo "== Permissões do n8n — APP=${APP:-local} — mql_candidates: cenário $MQL — $(date -u +%FT%TZ)"

# ---------- Carga B · n8n_contexto_cliente (Prospect Enrichment) ----------
B=n8n_contexto_cliente
t $B ok     "$SEARCH_PATH_OK"
t $B ok     "SELECT 1 FROM pipedrive_deals LIMIT 1"                                   # view sobre app (checa como a dona)
t $B ok     "SELECT 1 FROM chiefs_ativos LIMIT 1"
t $B ok     "SELECT id, enrichment_version FROM deal_enrichments WHERE deal_id = 0 AND is_active = TRUE"
t $B ok     "INSERT INTO deal_enrichments (deal_id, prospect_name, company, cargo, email) SELECT 0, '', '', '', '' WHERE false RETURNING enrichment_version"
t $B ok     "UPDATE deal_enrichments SET is_active = FALSE, updated_at = NOW() WHERE deal_id = 0 AND is_active = TRUE"
t $B ok     "WITH u AS (UPDATE deal_enrichments SET is_active = FALSE, updated_at = NOW() WHERE deal_id = 0 AND is_active = TRUE RETURNING id) SELECT count(*) FROM u"
t $B ok     "UPDATE deal_enrichments SET slack_message_ts = '', slack_channel_id = '' WHERE id = 0"
# node "Persist MQL Candidate" (SQL real, 17 colunas + ON CONFLICT DO UPDATE em 11) — cenário B: negado
t $B $MQL_OK "INSERT INTO mql_candidates (cnpj, org_name, person_name, person_email, cargo, area, nivel, decisor_comercial, setor, dor_setor, origem, stage_novo, tipo_origem, status, source, version, is_active) SELECT '', '', '', '', '', '', '', '', '', '', '', 'S0', 'New Business', 'open', 'n8n_netnew', 1, TRUE WHERE false ON CONFLICT (cnpj, person_name) DO UPDATE SET person_email=EXCLUDED.person_email, cargo=EXCLUDED.cargo, area=EXCLUDED.area, nivel=EXCLUDED.nivel, decisor_comercial=EXCLUDED.decisor_comercial, setor=EXCLUDED.setor, dor_setor=EXCLUDED.dor_setor, origem=EXCLUDED.origem, version=mql_candidates.version+1, is_active=TRUE, updated_at=NOW()"
t $B $MQL_OK "SELECT nextval(pg_get_serial_sequence('mql_candidates', 'id'))"          # ROLLBACK não desfaz nextval; só em teste
t $B $MQL_OK "SELECT 1 FROM mql_candidates LIMIT 1"
t $B ok     "SELECT nextval(pg_get_serial_sequence('deal_enrichments', 'id'))"
t $B negado "UPDATE deal_enrichments SET score_total = 0 WHERE false"                 # coluna fora da lista
t $B negado "UPDATE mql_candidates SET cnpj = cnpj WHERE false"
t $B negado "UPDATE mql_candidates SET source = source WHERE false"
t $B negado "DELETE FROM deal_enrichments WHERE false"
t $B negado "DELETE FROM mql_candidates WHERE false"
t $B negado "TRUNCATE deal_enrichments"
t $B negado "SELECT 1 FROM deal_sales_ops LIMIT 1"                                     # tabela da outra carga
t $B negado "INSERT INTO deal_sales_ops (deal_id) SELECT 0 WHERE false"
t $B negado "SELECT 1 FROM intelligence.users LIMIT 1"
t $B negado "SELECT 1 FROM app.pipedrive_deals LIMIT 1"                                # nada em app
t $B negado "SELECT 1 FROM app.chiefs LIMIT 1"
t $B negado "CREATE TABLE intelligence._t_perm (id int)"
t $B negado "CREATE TABLE public._t_perm (id int)"
t $B negado "ALTER TABLE deal_enrichments ADD COLUMN _t_perm int"

# ---------- Carga C · n8n_fila_salesops (Sales-Ops Cargo) ----------
C=n8n_fila_salesops
t $C ok     "$SEARCH_PATH_OK"
t $C ok     "SELECT 1 FROM pipedrive_deals LIMIT 1"
t $C ok     "SELECT id, version FROM deal_sales_ops WHERE deal_id = 0 AND is_active = TRUE"
t $C ok     "INSERT INTO deal_sales_ops (deal_id, contact_name, cargo, area, nivel) SELECT 0, '', '', '', '' WHERE false RETURNING *"
t $C ok     "UPDATE deal_sales_ops SET is_active = FALSE, updated_at = NOW() WHERE deal_id = 0 AND is_active = TRUE"
t $C ok     "WITH u AS (UPDATE deal_sales_ops SET is_active = FALSE, updated_at = NOW() WHERE deal_id = 0 AND is_active = TRUE RETURNING id, version) SELECT count(*) FROM u"
t $C ok     "SELECT nextval(pg_get_serial_sequence('deal_sales_ops', 'id'))"
t $C negado "UPDATE deal_sales_ops SET cargo = cargo WHERE false"                     # coluna fora da lista
t $C negado "UPDATE deal_sales_ops SET version = version WHERE false"
t $C negado "DELETE FROM deal_sales_ops WHERE false"
t $C negado "TRUNCATE deal_sales_ops"
t $C negado "SELECT 1 FROM deal_enrichments LIMIT 1"                                  # tabelas da outra carga
t $C negado "INSERT INTO deal_enrichments (deal_id, prospect_name, company) SELECT 0, '', '' WHERE false"
t $C negado "INSERT INTO mql_candidates (cnpj, org_name, person_name) SELECT '', '', '' WHERE false"
t $C negado "SELECT 1 FROM chiefs_ativos LIMIT 1"
t $C negado "SELECT 1 FROM app.pipedrive_deals LIMIT 1"
t $C negado "SELECT 1 FROM app.chiefs LIMIT 1"
t $C negado "CREATE TABLE intelligence._t_perm (id int)"
t $C negado "ALTER TABLE deal_sales_ops ADD COLUMN _t_perm int"

echo "== Resultado: $pass PASS, $fail FAIL"
[[ $fail -eq 0 ]]
