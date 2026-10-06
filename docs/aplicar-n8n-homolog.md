# Aplicar as credenciais do n8n na homolog (fluffy) — cenário B, 06/10/2026

**Executado em 06/10/2026 15h BRT (Amelia): 45 PASS, 0 FAIL** — evidências em
`evidencias/feedback-2026-10-05/00–04`. Mantido como receita para produção (§ final).

Escrita em base real: **só a Amelia executa.** Nada aqui toca produção nem a
origem Railway. Terminal zsh: rodar `setopt interactivecomments` antes, ou não
colar comentários na mesma linha.

```bash
setopt interactivecomments
cd ~/Documents/workspace/chiefs/chiefs-db-migration
APP=chiefsgroup-homolog
DB=postgresql-fluffy-10310
EV=evidencias/feedback-2026-10-05
mkdir -p $EV
DEFAULT_URL=$(heroku pg:credentials:url $DB --name default -a $APP | grep -oE 'postgres://[^ ]+' | head -1)
psql "$DEFAULT_URL" -Atc "select current_user, current_database()" | tee $EV/00-conexao.txt
```

Conferir que o banco é `devpemtfal8rfl` (homolog). Se não for, parar.

## 1 · Credenciais (Heroku; a default não tem CREATEROLE)

```bash
for r in n8n_contexto_cliente n8n_fila_salesops; do heroku pg:credentials:create $DB --name $r -a $APP; done
heroku pg:credentials $DB -a $APP | tee $EV/01-credenciais.txt
```

Repetir o segundo comando até as duas aparecerem `active`. **Não** rodar o
`addons:attach` que o Heroku sugere (exporia a credencial nas config vars).

## 2 · Grants (cenário B — mql_candidates fora)

```bash
psql "$DEFAULT_URL" -v ON_ERROR_STOP=1 -f ddl/p2-roles-n8n.sql 2>&1 | tee $EV/02-roles-n8n-homolog.txt
```

Esperado: relatório final com 5 linhas de privilégio por tabela
(`n8n_contexto_cliente`: `chiefs_ativos` SELECT, `deal_enrichments` INSERT,SELECT,
`pipedrive_deals` SELECT; `n8n_fila_salesops`: `deal_sales_ops` INSERT,SELECT,
`pipedrive_deals` SELECT) e 2 linhas de UPDATE por coluna
(`deal_enrichments`: is_active, slack_channel_id, slack_message_ts, updated_at;
`deal_sales_ops`: is_active, updated_at). Nenhuma linha de `mql_candidates`.
Se abortar com "matriz do n8n ... divergente", nada foi aplicado (transação única).

**Não** aplicar `ddl/p2-roles-n8n-mql-candidates.sql` (cenário A): só sob pedido
da Chiefs, depois do cutover.

## 3 · search_path (como cada credencial)

```bash
for u in n8n_contexto_cliente n8n_fila_salesops; do psql "$(heroku pg:credentials:url $DB --name $u -a $APP | grep -oE 'postgres://[^ ]+' | head -1)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-agentes.sql; done 2>&1 | tee $EV/03-search-path-n8n.txt
```

Esperado: 2 blocos com `{"search_path=intelligence, public, heroku_ext"}`.

## 4 · Teste permitido/negado (nada é gravado)

```bash
APP=$APP DB=$DB bash scripts/testa-permissoes-n8n.sh | tee $EV/04-permissoes-n8n-homolog.txt
```

Esperado: **`45 PASS, 0 FAIL`** (24 + 2 de `n8n_contexto_cliente`, 19 de
`n8n_fila_salesops`; as sondas do nó "Persist MQL Candidate" dão `negado`).
Validado em Docker em 06/10 com o mesmo resultado.

## 5 · Entregar ao Duda

URL de homolog das duas credenciais, por canal seguro (ele está sem o Heroku):

```bash
heroku pg:credentials:url $DB --name n8n_contexto_cliente -a $APP
heroku pg:credentials:url $DB --name n8n_fila_salesops -a $APP
```

Ele cria as duas credenciais no n8n, troca nos nodes do Prospect Enrichment e do
Sales-Ops Cargo e força um run de cada contra a homolog. A escrita fica em
`intelligence.deal_enrichments` / `deal_sales_ops` da fluffy (o próximo re-run do
ETL na homolog sobrescreve — combinado). Depois: registrar a data em
`p2/0. p2-entregas.md` e `p3/0. p3-entregas.md`.

## Rollback

```bash
psql "$DEFAULT_URL" -v ON_ERROR_STOP=1 -c "REVOKE ALL ON ALL TABLES IN SCHEMA intelligence FROM n8n_contexto_cliente, n8n_fila_salesops; REVOKE ALL ON ALL SEQUENCES IN SCHEMA intelligence FROM n8n_contexto_cliente, n8n_fila_salesops; REVOKE USAGE ON SCHEMA intelligence FROM n8n_contexto_cliente, n8n_fila_salesops;"
for r in n8n_contexto_cliente n8n_fila_salesops; do heroku pg:credentials:destroy $DB --name $r -a $APP; done
```

## Produção (quinta 08/10, na janela, depois da carga e do `etl/05-owner-intelligence.sql`)

Mesmos passos com `APP=chiefsgroup DB=postgresql-trapezoidal-33655` e
`EV=evidencias/producao-2026-10-08`; o passo 1 pode ser feito antes (terça,
banco vazio), os passos 2–4 só depois da carga. Mesmo esperado: 45/45.
