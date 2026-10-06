-- P2/P3 · Credenciais do n8n com conexão direta ao banco
-- (e-mail do Duda 29/09; v2 05/10 com a auditoria da instância de PROD do n8n;
--  v3 06/10: CENÁRIO B do Duda — mql_candidates FORA do grant, nó "Persist MQL
--  Candidate" desativado em PROD antes do dia D; o cenário A está pronto em
--  ddl/p2-roles-n8n-mql-candidates.sql para um pedido próprio, fora da janela)
--
-- Só 2 workflows do n8n abrem conexão direta, cada um serial (1 conexão):
-- o resto passa pela chiefs-api (intelligence_user). Uma credencial por
-- carga; hoje todos os nodes Postgres de todos os workflows dividem UMA
-- credencial no n8n ("PostgreSQL Chiefs") — separar no cutover.
--
-- Modelo de grant: SELECT e INSERT são por TABELA (cobrem todas as colunas
-- do INSERT, do WHERE e do RETURNING); UPDATE é por COLUNA (só o que o SQL
-- dos nodes escreve). mql_candidates: NENHUM privilégio para o n8n (cenário B,
-- 06/10) — a seção 5 aborta se houver.
--
-- Credencial            | carga                              | lê                                                  | escreve
-- ----------------------+------------------------------------+-----------------------------------------------------+---------------------------------------------------------------
-- n8n_contexto_cliente  | B · Prospect Enrichment (webhook   | pipedrive_deals*, deal_enrichments, chiefs_ativos*  | deal_enrichments: INSERT + UPDATE (is_active, slack_message_ts,
--                       |     enrich-prospect)               |                                                     |   slack_channel_id, updated_at)
--                       |                                    |                                                     | mql_candidates: NADA (nó "Persist MQL Candidate" desativado em PROD)
-- n8n_fila_salesops     | C · Sales-Ops Cargo (webhook       | pipedrive_deals*, deal_sales_ops                    | deal_sales_ops: INSERT + UPDATE (is_active, updated_at)
--                       |     sales-ops-cargo)               |                                                     |
--
-- * views de intelligence (dona: intelligence_user) sobre app.pipedrive_deals
--   e app.chiefs: a view checa permissão como a dona, então as credenciais do
--   n8n NÃO recebem nada em app.
-- Carga A (Chief Enrichment / Pipeline Automation) só via chiefs-api: sem credencial.
--
-- Sem DELETE/TRUNCATE, sem CREATE, sem default privileges: tabela nova para o
-- n8n entra por pedido e re-execução deste arquivo. Mesmos grants em homolog
-- e produção (é a escrita de produção do n8n). As queries dos nodes são sem
-- schema → search_path = intelligence na role (p2-search-path-agentes.sql).
--
-- Pré-requisito (Heroku; a default não tem CREATEROLE):
--   for r in n8n_contexto_cliente n8n_fila_salesops; do
--     heroku pg:credentials:create DATABASE_URL --name $r -a <app>; done
-- Executar conectado como a credencial DEFAULT (membro de intelligence_user),
-- DEPOIS da carga (as tabelas precisam existir) e do etl/05-owner-intelligence.sql:
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p2-roles-n8n.sql
-- Depois, conectado como CADA credencial: ddl/p2-search-path-agentes.sql
-- (search_path = intelligence, public, heroku_ext, o mesmo do serviço).
-- Teste permitido/negado: scripts/testa-permissoes-n8n.sh (SQL real dos nodes).
--
-- Idempotente.

\set ON_ERROR_STOP on

BEGIN;

-- 1 · Guard-rails
GRANT USAGE ON SCHEMA intelligence, public, heroku_ext TO n8n_contexto_cliente, n8n_fila_salesops;
REVOKE CREATE ON SCHEMA app, intelligence, analytical, lab, public FROM n8n_contexto_cliente, n8n_fila_salesops;
REVOKE ALL ON ALL TABLES    IN SCHEMA intelligence FROM n8n_contexto_cliente, n8n_fila_salesops;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA intelligence FROM n8n_contexto_cliente, n8n_fila_salesops;  -- re-concedidas na seção 4
REVOKE ALL ON ALL TABLES    IN SCHEMA app          FROM n8n_contexto_cliente, n8n_fila_salesops;

-- 2 · Carga B · n8n_contexto_cliente
GRANT SELECT ON intelligence.pipedrive_deals,
                intelligence.deal_enrichments,
                intelligence.chiefs_ativos
  TO n8n_contexto_cliente;
GRANT INSERT ON intelligence.deal_enrichments TO n8n_contexto_cliente;
-- UPDATE deal_enrichments SET is_active = FALSE, updated_at = NOW() WHERE deal_id = ... AND is_active = TRUE
-- UPDATE deal_enrichments SET slack_message_ts = ..., slack_channel_id = ... WHERE id = ...
GRANT UPDATE (is_active, slack_message_ts, slack_channel_id, updated_at)
  ON intelligence.deal_enrichments TO n8n_contexto_cliente;
-- mql_candidates: fora (cenário B). Se o cenário A voltar: ddl/p2-roles-n8n-mql-candidates.sql

-- 3 · Carga C · n8n_fila_salesops
GRANT SELECT ON intelligence.pipedrive_deals,
                intelligence.deal_sales_ops
  TO n8n_fila_salesops;
GRANT INSERT ON intelligence.deal_sales_ops TO n8n_fila_salesops;
-- UPDATE deal_sales_ops SET is_active = FALSE, updated_at = NOW() WHERE deal_id = ... AND is_active = TRUE
GRANT UPDATE (is_active, updated_at) ON intelligence.deal_sales_ops TO n8n_fila_salesops;

-- 4 · Sequences das tabelas com INSERT (nenhum INSERT dos nodes informa id)
DO $$
DECLARE r record; s text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('intelligence.deal_enrichments', 'n8n_contexto_cliente'),
      ('intelligence.deal_sales_ops',   'n8n_fila_salesops')) v(tab, grantee)
  LOOP
    s := pg_get_serial_sequence(r.tab, 'id');
    IF s IS NULL THEN
      RAISE EXCEPTION 'sem sequence em %.id — conferir a PK antes de liberar o INSERT', r.tab;
    END IF;
    EXECUTE format('GRANT USAGE ON SEQUENCE %s TO %I', s, r.grantee);
  END LOOP;
END $$;

-- 5 · Verificação por tabela: aborta se a matriz não bater
DO $$
DECLARE falhas text;
BEGIN
  SELECT string_agg(format('%s %s %s: esperado %s', t.papel, t.priv, t.obj, t.esperado), '; ')
    INTO falhas
    FROM (VALUES
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'INSERT', true),
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'SELECT', true),
      ('n8n_contexto_cliente', 'intelligence.chiefs_ativos',    'SELECT', true),
      ('n8n_contexto_cliente', 'intelligence.pipedrive_deals',  'SELECT', true),
      ('n8n_contexto_cliente', 'intelligence.mql_candidates',   'SELECT', false),   -- cenário B (06/10)
      ('n8n_contexto_cliente', 'intelligence.mql_candidates',   'INSERT', false),
      ('n8n_contexto_cliente', 'intelligence.mql_candidates',   'UPDATE', false),
      ('n8n_contexto_cliente', 'intelligence.mql_candidates',   'DELETE', false),
      ('n8n_contexto_cliente', 'intelligence.deal_sales_ops',   'SELECT', false),
      ('n8n_contexto_cliente', 'intelligence.deal_sales_ops',   'INSERT', false),
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'DELETE', false),
      ('n8n_fila_salesops',    'intelligence.mql_candidates',   'SELECT', false),
      ('n8n_contexto_cliente', 'intelligence.users',            'SELECT', false),
      ('n8n_contexto_cliente', 'app.pipedrive_deals',           'SELECT', false),
      ('n8n_contexto_cliente', 'app.chiefs',                    'SELECT', false),
      ('n8n_fila_salesops',    'intelligence.deal_sales_ops',   'INSERT', true),
      ('n8n_fila_salesops',    'intelligence.deal_sales_ops',   'SELECT', true),
      ('n8n_fila_salesops',    'intelligence.pipedrive_deals',  'SELECT', true),
      ('n8n_fila_salesops',    'intelligence.deal_enrichments', 'SELECT', false),
      ('n8n_fila_salesops',    'intelligence.deal_enrichments', 'INSERT', false),
      ('n8n_fila_salesops',    'intelligence.mql_candidates',   'INSERT', false),
      ('n8n_fila_salesops',    'intelligence.chiefs_ativos',    'SELECT', false),
      ('n8n_fila_salesops',    'intelligence.deal_sales_ops',   'DELETE', false),
      ('n8n_fila_salesops',    'app.chiefs',                    'SELECT', false)
    ) t(papel, obj, priv, esperado)
   WHERE has_table_privilege(t.papel, t.obj, t.priv) IS DISTINCT FROM t.esperado;
  IF falhas IS NOT NULL THEN
    RAISE EXCEPTION 'matriz do n8n (tabela) divergente: %', falhas;
  END IF;
END $$;

-- 6 · Verificação por coluna (UPDATE) + sequences
DO $$
DECLARE falhas text;
BEGIN
  -- UPDATE só nas colunas que os nodes escrevem; uma coluna "de fora" de cada tabela como controle negativo
  SELECT string_agg(format('%s UPDATE %s.%s: esperado %s', t.papel, t.obj, t.col, t.esperado), '; ')
    INTO falhas
    FROM (VALUES
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'is_active',        true),
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'slack_message_ts', true),
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'slack_channel_id', true),
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'updated_at',       true),
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'score_total',      false),
      ('n8n_contexto_cliente', 'intelligence.deal_enrichments', 'deal_id',          false),
      ('n8n_fila_salesops',    'intelligence.deal_sales_ops',   'is_active',        true),
      ('n8n_fila_salesops',    'intelligence.deal_sales_ops',   'updated_at',       true),
      ('n8n_fila_salesops',    'intelligence.deal_sales_ops',   'cargo',            false),
      ('n8n_fila_salesops',    'intelligence.deal_sales_ops',   'version',          false)
    ) t(papel, obj, col, esperado)
   WHERE has_column_privilege(t.papel, t.obj, t.col, 'UPDATE') IS DISTINCT FROM t.esperado;
  IF falhas IS NOT NULL THEN
    RAISE EXCEPTION 'matriz do n8n (coluna) divergente: %', falhas;
  END IF;

  -- sequences: USAGE para quem insere
  IF NOT has_sequence_privilege('n8n_contexto_cliente', pg_get_serial_sequence('intelligence.deal_enrichments', 'id'), 'USAGE')
     OR NOT has_sequence_privilege('n8n_fila_salesops',    pg_get_serial_sequence('intelligence.deal_sales_ops', 'id'), 'USAGE') THEN
    RAISE EXCEPTION 'USAGE de sequence faltando para o n8n';
  END IF;
  IF has_sequence_privilege('n8n_contexto_cliente', pg_get_serial_sequence('intelligence.mql_candidates', 'id'), 'USAGE') THEN
    RAISE EXCEPTION 'n8n_contexto_cliente com USAGE em mql_candidates_id_seq: cenário B não permite';
  END IF;
END $$;

COMMIT;

-- Relatório (para a evidência)
SELECT grantee, table_name, string_agg(privilege_type, ',' ORDER BY privilege_type) AS privs
  FROM information_schema.table_privileges
 WHERE grantee IN ('n8n_contexto_cliente', 'n8n_fila_salesops') AND table_schema = 'intelligence'
 GROUP BY 1, 2 ORDER BY 1, 2;
SELECT grantee, table_name, string_agg(column_name, ',' ORDER BY column_name) AS colunas_update
  FROM information_schema.column_privileges
 WHERE grantee IN ('n8n_contexto_cliente', 'n8n_fila_salesops') AND table_schema = 'intelligence'
   AND privilege_type = 'UPDATE'
 GROUP BY 1, 2 ORDER BY 1, 2;
