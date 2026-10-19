-- P3 · Monitoramento por credencial para o tl (pergunta do Renan 19/10)
--
-- Problema: intelligence_user vê <insufficient privilege> no pg_stat_statements
-- e não enxerga query/state das outras credenciais em pg_stat_activity.
-- pg_read_all_stats seria o caminho padrão, mas no Heroku a credencial default
-- não é superuser nem CREATEROLE e não é membro (com ADMIN) de
-- pg_read_all_stats → "permission denied to grant role". A seção 1 tenta mesmo
-- assim (se o Heroku permitir, melhor) e segue sem erro se for negado.
--
-- Caminho que funciona: a DEFAULT vê tudo (conferido na homolog 19/10: 0 linhas
-- com <insufficient privilege> em 4.566 statements de 22 userids; pg_stat_activity
-- com query das outras credenciais). Funções SECURITY DEFINER, owner default,
-- no schema lab, expondo só leitura e só o necessário; EXECUTE só para tl.
-- Nada de pg_signal_backend / pg_terminate_backend / reset.
--
-- Executar como a credencial DEFAULT, HML e PROD:
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p3-monitoramento-tl.sql
-- Uso (rubi/roma, herdam de tl):
--   SELECT * FROM lab.mon_statements(20);          -- top N por tempo total, por credencial
--   SELECT * FROM lab.mon_activity();              -- sessões ativas/idle in tx por credencial
--   SELECT * FROM lab.mon_locks();                 -- locks em espera
--   SELECT * FROM lab.mon_conexoes();              -- conexões por credencial × application_name
-- Idempotente.

\set ON_ERROR_STOP on

BEGIN;

-- 1 · Tentativa do caminho padrão (sem erro se o Heroku negar)
DO $$
BEGIN
  BEGIN
    EXECUTE 'GRANT pg_read_all_stats TO tl';
    RAISE NOTICE 'pg_read_all_stats concedido a tl';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'pg_read_all_stats NÃO concedível pela default (esperado no Heroku) — usando funções SECURITY DEFINER';
  END;
END $$;

-- 2 · Funções (owner = default = quem executa este arquivo)
GRANT USAGE ON SCHEMA lab TO tl;

CREATE OR REPLACE FUNCTION lab.mon_statements(p_limit int DEFAULT 20)
RETURNS TABLE (credencial text, calls bigint, total_exec_ms numeric, mean_exec_ms numeric, rows_ bigint, shared_blks_hit bigint, shared_blks_read bigint, query text)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT pg_get_userbyid(s.userid)::text,
         s.calls, round(s.total_exec_time::numeric, 1), round(s.mean_exec_time::numeric, 2),
         s.rows, s.shared_blks_hit, s.shared_blks_read,
         left(regexp_replace(s.query, '\s+', ' ', 'g'), 300)
    FROM public.pg_stat_statements s
    JOIN pg_database d ON d.oid = s.dbid AND d.datname = current_database()
   ORDER BY s.total_exec_time DESC
   LIMIT greatest(1, least(coalesce(p_limit, 20), 200));
$$;

CREATE OR REPLACE FUNCTION lab.mon_activity()
RETURNS TABLE (pid int, credencial text, application_name text, state text, wait_event_type text, wait_event text, since interval, query text)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = pg_catalog
AS $$
  SELECT a.pid, a.usename::text, a.application_name::text, a.state::text, a.wait_event_type::text, a.wait_event::text,
         now() - coalesce(a.query_start, a.backend_start),
         left(regexp_replace(a.query, '\s+', ' ', 'g'), 300)
    FROM pg_stat_activity a
   WHERE a.datname = current_database() AND a.backend_type = 'client backend' AND a.pid <> pg_backend_pid()
   ORDER BY a.state, a.query_start;
$$;

CREATE OR REPLACE FUNCTION lab.mon_locks()
RETURNS TABLE (pid int, credencial text, locktype text, relation text, mode text, granted boolean, waiting_for_pid int, query text)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = pg_catalog
AS $$
  SELECT l.pid, a.usename::text, l.locktype::text, l.relation::regclass::text, l.mode::text, l.granted,
         (pg_blocking_pids(l.pid))[1],
         left(regexp_replace(a.query, '\s+', ' ', 'g'), 300)
    FROM pg_locks l JOIN pg_stat_activity a ON a.pid = l.pid
   WHERE NOT l.granted
   ORDER BY l.pid;
$$;

CREATE OR REPLACE FUNCTION lab.mon_conexoes()
RETURNS TABLE (credencial text, application_name text, conexoes bigint, ativas bigint, idle_in_tx bigint)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = pg_catalog
AS $$
  SELECT a.usename::text, a.application_name::text, count(*),
         count(*) FILTER (WHERE a.state = 'active'),
         count(*) FILTER (WHERE a.state LIKE 'idle in transaction%')
    FROM pg_stat_activity a
   WHERE a.datname = current_database() AND a.backend_type = 'client backend'
   GROUP BY 1, 2 ORDER BY 1, 2;
$$;

REVOKE ALL ON FUNCTION lab.mon_statements(int), lab.mon_activity(), lab.mon_locks(), lab.mon_conexoes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lab.mon_statements(int), lab.mon_activity(), lab.mon_locks(), lab.mon_conexoes() TO tl;

COMMIT;

-- Verificação: tl executa; intelligence_user/worker não
SELECT r AS role,
       has_function_privilege(r, 'lab.mon_statements(int)', 'EXECUTE') AS statements,
       has_function_privilege(r, 'lab.mon_activity()', 'EXECUTE') AS activity
  FROM unnest(ARRAY['tl','worker','intelligence_user','analytical_reader','knowledge_app']) r
 WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r);
SELECT * FROM lab.mon_conexoes();
