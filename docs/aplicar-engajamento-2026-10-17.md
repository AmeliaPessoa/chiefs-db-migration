# Aplicar: page_views por coluna, view chief_status_versions, analytical via tl — 17/10/2026

**Executado em 17/10/2026 (Amelia):** HML passos 1–4 + prova do `SET ROLE tl`;
PROD passos 1 e 4 + `GRANT tl TO rubi, roma WITH SET TRUE`. Falta em PROD: view
(passo 2) e re-run do #912 (passo 3), após o OK do Renan às colunas. Evidências
em `evidencias/pos-cutover-2026-10-17/`. **Achado:** a membership em `tl` era
`SET FALSE` → `SET ROLE tl` negado; corrigido para `SET TRUE` (só `tl`;
`p2-roles-agentes.sql` atualizado).

Pedidos do Renan de 15/10 (fechamento do P3) e 15/10 (métrica de engajamento em
`analytical`). **Só a Amelia executa.** Ordem: **HML primeiro** (`chiefsgroup-homolog`
/ `postgresql-fluffy-10310`), depois PROD (`chiefsgroup` / `postgresql-trapezoidal-33655`).
Tudo aditivo ou em transação única; nada reinicia aplicação. Em 17/10 o Docker local
travou, então a aplicação em HML é a validação dos scripts antes de PROD; a regex da
view foi conferida na homolog em leitura (438 transições, distribuição no arquivo).

```bash
setopt interactivecomments
cd ~/Documents/workspace/chiefs/chiefs-db-migration
EV=evidencias/pos-cutover-2026-10-17; mkdir -p $EV
url() { heroku pg:credentials:url $DB --name $1 -a $APP | grep -oE 'postgres://[^ ]+' | head -1; }
```

## HML

```bash
APP=chiefsgroup-homolog; DB=postgresql-fluffy-10310; AMB=hml
DB_URL=$(url default); psql "$DB_URL" -Atc "select current_database()"      # devpemtfal8rfl
```

### 1 · page_views por coluna

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-page-views-por-coluna.sql 2>&1 | tee $EV/01-page-views-$AMB.txt
```

Esperado: `COMMIT` e 5 colunas listadas (`chief_id, created_at, event_at, path, startup_id`).

### 2 · View sem PII sobre app.versions (+ SELECT ao intelligence_user)

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-view-chief-status-versions.sql 2>&1 | tee $EV/02-view-chief-status-$AMB.txt
psql "$(url intelligence_user)" -c "select count(*) from app.chief_status_versions" -c "select 1 from app.versions limit 1" 2>&1 | tee $EV/02-view-como-intelligence-user-$AMB.txt
```

Esperado: `COMMIT`, amostra com `waiting_approval → active` etc.; como `intelligence_user`
o `count(*)` funciona (HML: 438) e o `select` em `app.versions` dá `permission denied`.

### 3 · Re-run do #912 (reconcilia tudo: page_views por coluna + grant na view)

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-intelligence-user-minimo.sql 2>&1 | tee $EV/03-912-$AMB.txt
```

Esperado: 4 linhas table-level (3 `active_campaign_*` + `chief_status_versions`),
**26 relações / 429 colunas**, 53 UPDATE, PII tudo `f`. **Se abortar, nada foi
aplicado**: mandar a saída antes de qualquer ajuste. (Ordem importa: a seção 26
exige a view do passo 2.)

### 4 · analytical: tl cria

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-analytical-tl.sql 2>&1 | tee $EV/04-analytical-tl-$AMB.txt
```

Esperado: `tl` com `usage = t, create = t`; `intelligence_user`, `analytical_reader`,
`looker_reader` com `usage = t, create = f`; `worker`/`app_user` `f, f`; default ACLs
listadas para `tl` e para a default.

Prova do desenho, como `rubi` (membro de `tl`), em HML apenas:

```bash
psql "$(url rubi)" -v ON_ERROR_STOP=1 -c "SET ROLE tl; CREATE TABLE analytical._prova_tl (id int); RESET ROLE;" -c "select relname, pg_get_userbyid(relowner) owner, has_table_privilege('intelligence_user','analytical._prova_tl','INSERT') iu_insert, has_table_privilege('looker_reader','analytical._prova_tl','SELECT') looker_select, has_table_privilege('intelligence_user','analytical._prova_tl','DELETE') iu_delete from pg_class where relname='_prova_tl'" -c "SET ROLE tl; DROP TABLE analytical._prova_tl;" 2>&1 | tee $EV/04-prova-tl-$AMB.txt
```

Esperado: owner `tl`, `iu_insert = t`, `looker_select = t`, `iu_delete = f`.

## PROD (depois do HML limpo)

```bash
APP=chiefsgroup; DB=postgresql-trapezoidal-33655; AMB=prod
DB_URL=$(url default); psql "$DB_URL" -Atc "select current_database()"      # dfiit9c72iv839
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-page-views-por-coluna.sql 2>&1 | tee $EV/01-page-views-$AMB.txt
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-analytical-tl.sql 2>&1 | tee $EV/04-analytical-tl-$AMB.txt
```

A view em PROD (passos 2 e 3) só depois do OK do Renan às colunas, no mesmo
roteiro. **Não** rodar o #912 em PROD antes do passo 2 lá: a seção 26 falharia
(view inexistente) e nada seria aplicado.

## Depois

- Avisar na thread: page_views por coluna em HML e PROD; view em HML para o
  backtest; analytical pronto nos dois. Renan valida `count(*)` da
  `chief_engajamento` como `intelligence_user`.
- Registrar em `p2/0. p2-entregas.md`; commitar `ddl/p3-*.sql`, o #912 e as
  evidências (sem URL/senha).
