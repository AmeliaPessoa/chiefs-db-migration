-- P2/P3 · search_path da role intelligence_user
-- (feedback Chiefs 08/09, item 2 — teste de cutover Variante D-2 em homolog)
--
-- Sem search_path a role cai em `public` e não enxerga intelligence.*.
-- Padrão proposto para PRODUÇÃO: search_path NA ROLE (como app_user no P1,
-- p1-schemas-roles-grants.sql §8), e a connection string SEM `options=`.
-- Motivo: fica no banco, sobrevive a troca de connection string/segredo e a
-- rotação de credencial (runbook do P1), e vale para qualquer cliente que
-- conecte com a role (psql, workers, n8n). A connection string continua
-- podendo sobrescrever — passar search_path lá é redundante, não conflita.
--
-- ⚠ Executar conectado como o PRÓPRIO intelligence_user (uma role altera as
--   próprias configs; a credencial default NÃO tem CREATEROLE no Heroku —
--   "permission denied to alter role", constatado no P1 em 19/08):
--   psql "$(heroku pg:credentials:url DATABASE_URL --name intelligence_user -a <app> | grep -oE 'postgres://[^ ]+')" \
--        -v ON_ERROR_STOP=1 -f ddl/p2-search-path-intelligence-user.sql
-- Vale para conexões NOVAS (as abertas mantêm o search_path antigo).

\set ON_ERROR_STOP on

DO $$ BEGIN
  EXECUTE format('ALTER ROLE intelligence_user IN DATABASE %I SET search_path = intelligence, public, heroku_ext',
                 current_database());
END $$;

-- Verificação (nova sessão): espera-se "intelligence, public, heroku_ext"
SELECT r.rolname, s.setconfig
  FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
 WHERE r.rolname = 'intelligence_user';
