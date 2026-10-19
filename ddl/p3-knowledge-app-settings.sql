-- P3 · knowledge_app: search_path e statement_timeout NA ROLE (seção 5 do p3-knowledge.sql)
-- ⚠ Executar conectado como o PRÓPRIO knowledge_app (a default não altera outra role no Heroku):
--   psql "$(heroku pg:credentials:url <addon> --name knowledge_app -a <app> | grep -oE 'postgres://[^ ]+')" -v ON_ERROR_STOP=1 -f ddl/p3-knowledge-app-settings.sql
-- CONNECTION LIMIT não é configurável aqui (atributo de role; exige CREATEROLE) → pool do módulo ≤ 5.
\set ON_ERROR_STOP on
DO $$ BEGIN
  EXECUTE format('ALTER ROLE %I IN DATABASE %I SET search_path = knowledge, intelligence, public, heroku_ext', current_user, current_database());
  EXECUTE format('ALTER ROLE %I IN DATABASE %I SET statement_timeout = %L', current_user, current_database(), '30s');
END $$;
SELECT r.rolname, s.setconfig FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole WHERE r.rolname = current_user;
