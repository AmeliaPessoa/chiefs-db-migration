-- P3 · app.page_views: de tabela inteira para SELECT por coluna (Renan 15/10:
-- a view intelligence.chief_engajamento, migration 118, lê só chief_id, path,
-- event_at e created_at; startup_id entra para uso futuro). Tira user_agent,
-- facebook_cookie_id e google_cookie_id do alcance do intelligence_user (§5.1).
-- Transação única: nenhuma janela sem grant. Mesmo conteúdo que a seção 25 do
-- ddl/p2-grants-intelligence-user-minimo.sql (que é a fonte da verdade).
-- Executar como a credencial DEFAULT, em HML e PROD:
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p3-page-views-por-coluna.sql

\set ON_ERROR_STOP on
BEGIN;
REVOKE SELECT ON app.page_views FROM intelligence_user;
GRANT SELECT (chief_id, startup_id, path, event_at, created_at) ON app.page_views TO intelligence_user;
DO $$
BEGIN
  IF has_table_privilege('intelligence_user', 'app.page_views', 'SELECT') THEN
    RAISE EXCEPTION 'intelligence_user ainda com SELECT de tabela em page_views';
  END IF;
  IF NOT has_column_privilege('intelligence_user', 'app.page_views', 'chief_id', 'SELECT')
     OR has_column_privilege('intelligence_user', 'app.page_views', 'user_agent', 'SELECT')
     OR has_column_privilege('intelligence_user', 'app.page_views', 'facebook_cookie_id', 'SELECT') THEN
    RAISE EXCEPTION 'grant por coluna em page_views divergente';
  END IF;
END $$;
COMMIT;
SELECT column_name FROM information_schema.column_privileges
 WHERE grantee = 'intelligence_user' AND table_schema = 'app' AND table_name = 'page_views' AND privilege_type = 'SELECT'
 ORDER BY 1;
