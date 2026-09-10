-- P2 ETL · 06 — ANALYZE pós-carga (app + intelligence)
-- (feedback Chiefs 10/09, item 8 — passo fixo no fim da carga)
--
-- Por quê: carga por TRUNCATE+COPY e merge por UPDATE em massa deixam o
-- planner sem estatística até o autovacuum passar (na homolog em 10/09:
-- 31 tabelas de app e 4 de intelligence com dado e last_analyze NULL;
-- planos "no escuro" distorcem a discussão de índices do item 3).
--
-- Executar como a credencial DEFAULT (owner ou membro do owner de cada
-- tabela — ANALYZE exige isso, ou MAINTAIN no PG ≥ 17). Tabela sem
-- privilégio é pulada com WARNING, não erro. O etl.py faz o mesmo ao fim
-- da carga (analyze_tables). Pode rodar a qualquer momento; não bloqueia
-- escrita (só ShareUpdateExclusiveLock).
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f etl/06-analyze.sql

\set ON_ERROR_STOP on

DO $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT n.nspname, c.relname
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname IN ('app', 'intelligence') AND c.relkind IN ('r', 'p', 'm')
     ORDER BY 1, 2
  LOOP
    EXECUTE format('ANALYZE %I.%I', r.nspname, r.relname);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'ANALYZE: % tabela(s)', n;
END $$;

-- Verificação: zero tabelas com dado e sem estatística
SELECT schemaname,
       count(*) AS tabelas,
       count(*) FILTER (WHERE n_live_tup > 0 AND last_analyze IS NULL AND last_autoanalyze IS NULL) AS com_dado_sem_stats,
       max(last_analyze) AS ultimo_analyze
  FROM pg_stat_user_tables
 WHERE schemaname IN ('app', 'intelligence')
 GROUP BY 1 ORDER BY 1;
