-- P3 · intelligence_ro: credencial de SERVIÇO somente leitura para os services do
-- Railway e para o n8n (DATABASE_URL_PROD_RO), no lugar da role PESSOAL rubi
-- (incidente Railway QH8L8B3E, 21/10/2026 — pedido da Chiefs 22/10)
--
-- Por que não rubi: rubi é pessoa (TL), membro de tl com SET TRUE → quem tem a
-- URL dela escreve nas 7 tabelas do tl, cria objetos em analytical/knowledge via
-- SET ROLE tl e executa as funções de monitoramento. Uma variável de serviço com
-- essa URL é um caminho de escrita e de DDL disfarçado de "read-only".
--
-- Desenho: intelligence_ro é membro de analytical_reader (INHERIT, sem SET) e
-- nada mais → SELECT na allowlist de app (a mesma do intelligence_user), em
-- intelligence.* e em analytical.*; nenhuma escrita, nenhum CREATE, nenhuma
-- função de monitoramento. É a matriz já testada (26 sondas comuns + 3 do reader).
--
-- Pré-requisito (Heroku): heroku pg:credentials:create <addon> --name intelligence_ro -a <app>
-- Executar como a credencial DEFAULT; depois ddl/p2-search-path-agentes.sql como
-- intelligence_ro. Idempotente.

\set ON_ERROR_STOP on

BEGIN;
GRANT analytical_reader TO intelligence_ro WITH INHERIT TRUE, SET FALSE;
REVOKE CREATE ON SCHEMA app, intelligence, analytical, lab, public FROM intelligence_ro;
DO $$ BEGIN
  IF to_regnamespace('knowledge') IS NOT NULL THEN REVOKE CREATE ON SCHEMA knowledge FROM intelligence_ro; END IF;
  IF to_regnamespace('comercial') IS NOT NULL THEN REVOKE CREATE ON SCHEMA comercial FROM intelligence_ro; END IF;
END $$;
DO $$
BEGIN
  IF NOT pg_has_role('intelligence_ro', 'analytical_reader', 'USAGE') THEN RAISE EXCEPTION 'intelligence_ro não herda analytical_reader'; END IF;
  IF pg_has_role('intelligence_ro', 'tl', 'USAGE') OR pg_has_role('intelligence_ro', 'worker', 'USAGE') THEN RAISE EXCEPTION 'intelligence_ro em tl/worker'; END IF;
  IF has_table_privilege('intelligence_ro', 'intelligence.jd_results', 'INSERT') THEN RAISE EXCEPTION 'intelligence_ro com INSERT'; END IF;
  IF has_function_privilege('intelligence_ro', 'lab.mon_conexoes()', 'EXECUTE') THEN RAISE EXCEPTION 'intelligence_ro executa monitoramento'; END IF;
END $$;
COMMIT;

SELECT g.rolname AS grupo, m.inherit_option, m.set_option
  FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid JOIN pg_roles u ON u.oid = m.member
 WHERE u.rolname = 'intelligence_ro';
SELECT has_table_privilege('intelligence_ro', 'intelligence.jd_results', 'SELECT') AS le_intelligence,
       has_column_privilege('intelligence_ro', 'app.chiefs', 'name', 'SELECT')      AS le_allowlist,
       has_column_privilege('intelligence_ro', 'app.chiefs', 'encrypted_password', 'SELECT') AS le_senha,
       has_table_privilege('intelligence_ro', 'intelligence.jd_results', 'UPDATE') AS escreve,
       has_schema_privilege('intelligence_ro', 'analytical', 'CREATE')             AS cria;
