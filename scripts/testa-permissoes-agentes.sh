#!/usr/bin/env bash
# P2/P3 · Teste permitido/negado dos usuários de agente (ddl/p2-roles-agentes.sql)
#
# Conecta como CADA usuário (credencial própria via heroku pg:credentials:url)
# e roda cada comando dentro de BEGIN … ROLLBACK: nada é gravado. Escritas
# usam WHERE false / INSERT … SELECT … WHERE false — o Postgres checa o
# privilégio mesmo sem linha afetada, e nenhuma linha é tocada.
#
# Uso (a partir da raiz do repo):
#   APP=chiefsgroup-homolog AMBIENTE=homolog bash scripts/testa-permissoes-agentes.sh \
#     | tee evidencias/feedback-2026-09-22/NN-permissoes-agentes-homolog.txt
#   (produção: AMBIENTE=producao — o worker passa a ser só leitura)
set -uo pipefail

: "${APP:?defina APP=<app-heroku>}"
: "${AMBIENTE:?defina AMBIENTE=homolog|producao}"
DB="${DB:-DATABASE_URL}"
CACHE="$(mktemp -d)"; trap 'rm -rf "$CACHE"' EXIT   # bash 3.2 (macOS): sem array associativo
pass=0; fail=0

url_de() {
  [[ -s "$CACHE/$1" ]] || heroku pg:credentials:url "$DB" --name "$1" -a "$APP" | grep -oE 'postgres://[^ ]+' | head -1 > "$CACHE/$1"
  cat "$CACHE/$1"
}

# t <usuario> <ok|negado> <sql>
t() {
  local u="$1" esperado="$2" sql="$3" out obtido
  out="$(psql "$(url_de "$u")" -X -q -v ON_ERROR_STOP=1 -c "BEGIN; $sql; ROLLBACK;" 2>&1)"
  if [[ $? -eq 0 ]]; then obtido=ok
  elif grep -q "permission denied\|must be owner" <<<"$out"; then obtido=negado
  else obtido="ERRO: $(head -1 <<<"$out")"; fi
  if [[ "$obtido" == "$esperado" ]]; then ((pass++)); printf 'PASS  %-9s %-7s %s\n' "$u" "$esperado" "$sql"
  else ((fail++)); printf 'FAIL  %-9s esperado=%s obtido=%s  %s\n' "$u" "$esperado" "$obtido" "$sql"; fi
}

usa_schema() { echo "DO \$\$ BEGIN IF NOT has_schema_privilege('$1','USAGE') THEN RAISE 'permission denied for schema $1'; END IF; END \$\$"; }
ins() { echo "INSERT INTO $1 SELECT * FROM $1 WHERE false"; }

echo "== Permissões dos agentes — APP=$APP AMBIENTE=$AMBIENTE — $(date -u +%FT%TZ)"

# Comum a todos os usuários
for u in rubi roma jade safira tokyo bogota ametista oslo; do
  t "$u" ok     "SELECT 1 FROM app.chiefs LIMIT 1"
  t "$u" ok     "SELECT 1 FROM intelligence.job_descriptions LIMIT 1"
  t "$u" ok     "SELECT 1 FROM intelligence.chief_embeddings LIMIT 1"
  t "$u" ok     "SELECT similarity('a', 'b')"                                   # USAGE public + search_path
  t "$u" ok     "DO \$\$ BEGIN IF current_setting('search_path') !~ '^intelligence' THEN RAISE 'search_path errado: %', current_setting('search_path'); END IF; END \$\$"
  t "$u" negado "UPDATE app.chiefs SET name = name WHERE false"
  t "$u" negado "$(ins app.chiefs)"
  t "$u" negado "DELETE FROM intelligence.jd_results WHERE false"
  t "$u" negado "TRUNCATE intelligence.jd_results"
  t "$u" negado "CREATE TABLE intelligence._t_perm (id int)"
  t "$u" negado "CREATE TABLE app._t_perm (id int)"
  t "$u" negado "CREATE TABLE public._t_perm (id int)"
  t "$u" negado "CREATE TABLE lab._t_perm (id int)"
  t "$u" negado "ALTER TABLE intelligence.jd_results ADD COLUMN _t_perm int"
done

# tl — correção de dado autorizada (homolog = produção)
for u in rubi roma; do
  t "$u" ok     "$(usa_schema analytical)"
  t "$u" ok     "$(ins intelligence.jd_results)"
  t "$u" ok     "UPDATE intelligence.jd_results SET id = id WHERE false"
  t "$u" ok     "UPDATE intelligence.platform_sync_state SET last_sync_at = last_sync_at WHERE false"
  t "$u" negado "$(ins intelligence.job_descriptions)"                       # fora da lista do tl
done

# worker
for u in jade safira tokyo bogota; do
  t "$u" negado "$(usa_schema analytical)"
  if [[ "$AMBIENTE" == homolog ]]; then
    t "$u" ok     "$(ins intelligence.job_descriptions)"
    t "$u" ok     "UPDATE intelligence.job_descriptions SET id = id WHERE false"
    t "$u" ok     "$(ins intelligence.pipeline_runs)"
    t "$u" negado "UPDATE intelligence.pipeline_runs SET id = id WHERE false"  # append-only
    t "$u" negado "$(ins intelligence.platform_sync_state)"                    # fora da lista do worker
  else
    t "$u" negado "$(ins intelligence.job_descriptions)"
    t "$u" negado "UPDATE intelligence.jd_results SET id = id WHERE false"
    t "$u" negado "$(ins intelligence.pipeline_runs)"
  fi
done

# reader (analytical_reader)
for u in ametista oslo; do
  t "$u" ok     "$(usa_schema analytical)"
  t "$u" negado "$(ins intelligence.jd_results)"
  t "$u" negado "UPDATE intelligence.jd_results SET id = id WHERE false"
done

echo "== Resultado: $pass PASS, $fail FAIL"
[[ $fail -eq 0 ]]
