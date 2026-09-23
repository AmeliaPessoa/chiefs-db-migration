-- P2/P3 · search_path na role de cada usuário de agente
-- (mapas do Renan 16/09 e do Bruno 21/09: "search_path fica na role, como já
--  está pro intelligence_user" — mesmo valor, para nome sem prefixo resolver
--  igual ao serviço)
--
-- search_path NÃO é herdado do grupo: precisa estar em cada usuário
-- (rubi, jade, safira, ametista, roma, tokyo, bogota, oslo).
--
-- ⚠ Executar conectado como o PRÓPRIO usuário (a default não tem CREATEROLE):
--   for u in rubi jade safira ametista roma tokyo bogota oslo; do
--     psql "$(heroku pg:credentials:url DATABASE_URL --name $u -a <app> | grep -oE 'postgres://[^ ]+')" \
--          -v ON_ERROR_STOP=1 -f ddl/p2-search-path-agentes.sql
--   done
-- Vale para conexões NOVAS.

\set ON_ERROR_STOP on

DO $$ BEGIN
  EXECUTE format('ALTER ROLE %I IN DATABASE %I SET search_path = intelligence, public, heroku_ext',
                 current_user, current_database());
END $$;

SELECT r.rolname, s.setconfig
  FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
 WHERE r.rolname = current_user;
