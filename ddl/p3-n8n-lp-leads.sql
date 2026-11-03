-- P3 · n8n_lp_leads: credencial de SERVIÇO do workflow n8n "leads das landing
-- pages" (O3KR3) — criada pela Chiefs na fluffy em 03/11/2026 no modelo da
-- radar_app (heroku pg:credentials:create, sem attach); PINK só sob pedido.
--
-- Escopo (Renan, 03/11): USAGE em intelligence; SELECT, INSERT, UPDATE em
-- intelligence.lp_leads (sem DELETE) — o node faz INSERT … ON CONFLICT
-- (dedupe_key) DO UPDATE; USAGE, SELECT na sequence lp_leads_id_seq. Nada em
-- app, nada nas outras tabelas de intelligence. Na role (feito pela Chiefs):
-- search_path = intelligence, public, heroku_ext; statement_timeout = 30s.
--
-- lp_leads é tabela do Alembic (125_lp_leads_is_deleted), owner intelligence_user,
-- fora do ETL — nenhum script deste repo a recria ou revoga grants dela; este
-- arquivo existe para que um re-apply dos grants deixe a role como está e para
-- que a verificação acuse drift. Executar como a credencial DEFAULT. Idempotente.
-- Se a tabela ainda não existir (PINK antes da migration), só avisa e sai.

\set ON_ERROR_STOP on

BEGIN;
DO $$
BEGIN
  IF to_regrole('n8n_lp_leads') IS NULL THEN
    RAISE EXCEPTION 'role n8n_lp_leads não existe: heroku pg:credentials:create <addon> --name n8n_lp_leads -a <app>';
  END IF;
  IF to_regclass('intelligence.lp_leads') IS NULL THEN
    RAISE WARNING 'intelligence.lp_leads não existe neste banco (Alembic < 125?) — grants da tabela NÃO aplicados';
  END IF;
END $$;

GRANT USAGE ON SCHEMA intelligence TO n8n_lp_leads;
REVOKE CREATE ON SCHEMA app, intelligence, analytical, lab, public FROM n8n_lp_leads;
DO $$ BEGIN
  IF to_regnamespace('knowledge') IS NOT NULL THEN REVOKE CREATE ON SCHEMA knowledge FROM n8n_lp_leads; END IF;
  IF to_regnamespace('comercial') IS NOT NULL THEN REVOKE CREATE ON SCHEMA comercial FROM n8n_lp_leads; END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('intelligence.lp_leads') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON intelligence.lp_leads TO n8n_lp_leads';
    EXECUTE 'REVOKE DELETE, TRUNCATE, REFERENCES, TRIGGER ON intelligence.lp_leads FROM n8n_lp_leads';
    EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE intelligence.lp_leads_id_seq TO n8n_lp_leads';
    EXECUTE 'REVOKE UPDATE ON SEQUENCE intelligence.lp_leads_id_seq FROM n8n_lp_leads';
  END IF;
END $$;

-- Verificação (drift): nada além do escopo
DO $$
DECLARE n int;
BEGIN
  IF to_regclass('intelligence.lp_leads') IS NULL THEN RETURN; END IF;
  SELECT count(*) INTO n FROM information_schema.table_privileges
   WHERE grantee = 'n8n_lp_leads' AND NOT (table_schema = 'intelligence' AND table_name = 'lp_leads');
  IF n > 0 THEN RAISE EXCEPTION 'n8n_lp_leads com privilégio em outra tabela (% linhas)', n; END IF;
  IF has_table_privilege('n8n_lp_leads', 'intelligence.lp_leads', 'DELETE') THEN RAISE EXCEPTION 'n8n_lp_leads com DELETE'; END IF;
  IF has_schema_privilege('n8n_lp_leads', 'app', 'USAGE') THEN RAISE EXCEPTION 'n8n_lp_leads com USAGE em app'; END IF;
  IF pg_has_role('n8n_lp_leads', 'tl', 'USAGE') OR pg_has_role('n8n_lp_leads', 'worker', 'USAGE')
     OR pg_has_role('n8n_lp_leads', 'analytical_reader', 'USAGE') THEN RAISE EXCEPTION 'n8n_lp_leads em grupo de agentes'; END IF;
END $$;
COMMIT;

SELECT has_table_privilege('n8n_lp_leads', 'intelligence.lp_leads', 'SELECT')  AS le,
       has_table_privilege('n8n_lp_leads', 'intelligence.lp_leads', 'INSERT')  AS insere,
       has_table_privilege('n8n_lp_leads', 'intelligence.lp_leads', 'UPDATE')  AS atualiza,
       has_table_privilege('n8n_lp_leads', 'intelligence.lp_leads', 'DELETE')  AS apaga,
       has_sequence_privilege('n8n_lp_leads', 'intelligence.lp_leads_id_seq', 'USAGE') AS seq,
       has_table_privilege('n8n_lp_leads', 'intelligence.chiefs_todos', 'SELECT') AS le_chiefs,
       has_schema_privilege('n8n_lp_leads', 'app', 'USAGE')                    AS usa_app,
       has_schema_privilege('n8n_lp_leads', 'intelligence', 'CREATE')          AS cria
 WHERE to_regclass('intelligence.lp_leads') IS NOT NULL;
SELECT setconfig FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole WHERE r.rolname = 'n8n_lp_leads';
