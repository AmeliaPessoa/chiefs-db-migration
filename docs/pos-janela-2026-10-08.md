# Pós-janela — quinta 08/10/2026 (observação de 48h)

Cutover feito com **GO às 11:26 BRT**. Produção: Rails e Intelligence no
`postgresql-trapezoidal-33655` (PINK, db `dfiit9c72iv839`). Essential-1
(`postgresql-triangular-22490`, RED) e o Railway `chiefs_intelligence` ficam
**intocados até o aceite do P3**.

Perna da Amelia na janela (`evidencias/janela-2026-10-08/tempos.txt`):

| Etapa | Tempo |
|---|---|
| backup do RED (b252, 108,88 MB) | 28 s |
| pg:copy (99 tabelas) | 44 s |
| pg:promote + attach `app_user` (v1339) | 50 s |
| P1 (97 tabelas para `app`, owner, USAGE) | 1 min 18 s |
| DDL | 47 s |
| re-diff (0 DRIFT) | 23 s |
| ETL 49 tabelas + merge + HNSW (428.753 linhas, ZERO DIVERGÊNCIAS) | 5 min 20 s |
| #912 (24 tabelas / 414 colunas, 53 UPDATE) + search_path | 7 s |
| **total, 13:05:46 → 13:19:41 UTC** | **13 min 55 s** |

Depois do "banco pronto" (10:20 BRT) a Chiefs fez: alembic 116 (10:47), smoke
por conteúdo (10:49), **2 GIN + 1 FTS em `app.chiefs` com nomes próprios**,
**grants do n8n pela matriz da auditoria de 05/10 (11:17)**, troca das
credenciais nos 8 nós, religamento (11:26–11:50). Os passos 11–13 do roteiro
(índices, `p2-roles-agentes.sql`, `p2-roles-n8n.sql`, testes 360/45) **não
rodaram pela Amelia**; ficam aqui como pós-janela. Nada bloqueante.

## O que fazer agora (Amelia, com a produção viva — tudo aditivo ou idempotente)

```bash
setopt interactivecomments
cd ~/Documents/workspace/chiefs/chiefs-db-migration
APP=chiefsgroup
DB=postgresql-trapezoidal-33655
EV=evidencias/janela-2026-10-08
url() { heroku pg:credentials:url $DB --name $1 -a $APP | grep -oE 'postgres://[^ ]+' | head -1; }
DB_URL=$(url default)
psql "$DB_URL" -Atc "select current_database()"        # dfiit9c72iv839
```

### 1 · Inventário dos índices de `app.chiefs` (leitura)

```bash
psql "$DB_URL" -c "select indexname, indisvalid, pg_size_pretty(pg_relation_size(i.indexrelid)) tam, indexdef from pg_indexes x join pg_index i on i.indexrelid = (x.schemaname||'.'||x.indexname)::regclass where x.schemaname='app' and x.tablename='chiefs' order by 1" | tee $EV/12-indices-chiefs-inventario.txt
```

Esperado: os 5 do Rails + `idx_chiefs_industries_text_trgm`,
`idx_chiefs_all_job_titles_trgm`, `idx_chiefs_fts_pt_view` (Chiefs) e talvez
`idx_chiefs_fts_pt` (a Chiefs vai dropar). **Faltam os 3 B-tree.**

### 2 · Os 3 B-tree que faltam (CONCURRENTLY, banco vivo)

O arquivo `ddl/ddl-main-enrichment-indexes.sql` agora pula os GIN quando já
existe índice com a mesma expressão (nomes da Chiefs), então pode rodar inteiro:

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/ddl-main-enrichment-indexes.sql 2>&1 | tee $EV/12-indices-btree.txt
```

Esperado: `pg_trgm em heroku_ext`, 3 `CREATE INDEX`, dois avisos "já existe
(outro nome) — pulando", e a verificação final com tudo `indisvalid = t`.

### 3 · n8n: reconciliar com o nosso arquivo (idempotente, uma transação)

A Chiefs aplicou a matriz à mão às 11:17. O `p2-roles-n8n.sql` revoga e
reconcede exatamente a mesma matriz numa transação (sem janela sem grant) e
**aborta se algo divergir**, então é a conferência e a padronização ao mesmo
tempo. Os workflows já estão republicados: avisar o Renan antes, por cortesia
(nada cai).

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p2-roles-n8n.sql 2>&1 | tee $EV/13-roles-n8n.txt
APP=$APP DB=$DB bash scripts/testa-permissoes-n8n.sh | tee $EV/13-teste-n8n.txt     # 45 PASS, 0 FAIL
```

Se o arquivo abortar com "matriz do n8n divergente", nada foi alterado: mandar a
mensagem de erro para cá antes de qualquer ajuste.

### 4 · Agentes (roles existem desde 06/10, ninguém usa ainda)

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -v ambiente=producao -f ddl/p2-roles-agentes.sql 2>&1 | tee $EV/14-roles-agentes.txt
APP=$APP DB=$DB AMBIENTE=producao bash scripts/testa-permissoes-agentes.sh | tee $EV/14-teste-agentes.txt   # 360 PASS, 0 FAIL
```

Esperado: 12 memberships, escrita só do `tl` (7 linhas), 21 tabelas por grupo em
`app`. Só então entregar as URLs: rubi, jade, safira, ametista → Renan; roma,
tokyo, bogota, oslo → Bruno; raiz, grass, ocean, white → Duda (via Renan).

### 5 · Conexões e sanidade (leitura)

```bash
psql "$DB_URL" -c "select usename, application_name, count(*) from pg_stat_activity where datname = current_database() group by 1,2 order by 1,2" | tee $EV/15-conexoes.txt
heroku pg:info DATABASE_URL -a $APP | head -3
heroku pg:info postgresql-triangular-22490 -a $APP | grep -E "Plan|Tables|Data Size"   # essential-1 intocado
```

Esperado: nenhuma conexão de aplicação pela default (`uas9q88ghnhmgm`), só
`app_user`, `intelligence_user`, `n8n_*`.

## Achados da janela a registrar

- **10 views `vw_ca_*` ficaram em `public`** (financeiro Conta Azul: MRR,
  inadimplência, LTV, take rate, comissão), owner default. Funcionam (view
  aponta para a tabela por OID). Perguntar ao Renan quem as consome e se vão
  para `analytical` (lugar delas no desenho) — fora da janela, com aviso ao BI.
- Em produção os GIN têm nomes da Chiefs; o arquivo de índices passou a
  reconhecer por expressão.
- Índice de `industries_experience` não é usado pela view (cast externo
  STABLE) — ajuste é no código da busca (card da Chiefs); 39 ms hoje.
- `idx_chiefs_fts_pt` (inútil) será dropado pela Chiefs.
- Contato durante a observação de 48h: combinar canal e horário com o Renan.

## Próximos entregáveis

1. Relatório técnico de validação do **P3** (template §11.2): tempos, dry-run,
   rollback, smoke, sequences, origens ainda ligadas → aceite formal.
2. Depois do aceite: plano de desligamento das origens (Railway
   `chiefs_intelligence` e essential-1) com backup final arquivado e aprovação
   explícita do Renan; destino do RDS por escrito; encerramento contratual
   (revogar acessos da prestadora, rotação de credenciais, runbooks finais).
