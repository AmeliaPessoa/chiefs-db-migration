-- P2 ETL · 05 — Owner dos objetos de intelligence.* = intelligence_user
-- (feedback Chiefs 08/09, item 5 — passo FINAL do ETL, após a carga)
--
-- Por quê: as migrations Alembic do Intelligence fazem ALTER TABLE / CREATE
-- INDEX, e o Postgres exige ser OWNER para isso (o deploy de teste falhou com
-- "must be owner of table job_descriptions" quando as tabelas ficaram com a
-- credencial default). CRUD via grant não basta.
--
-- Executar como a credencial DEFAULT (dona atual dos objetos e membro de
-- intelligence_user — ALTER OWNER exige as duas coisas). Idempotente: só
-- toca o que ainda não é do intelligence_user. Cobre tabelas, partições,
-- sequences, views e matviews do schema; o SCHEMA em si continua da default
-- (intelligence_user tem CREATE nele — basta para as migrations).
-- O etl.py faz o mesmo automaticamente ao fim da carga (DST_OBJECT_OWNER).
--
-- Depois disso a credencial default continua operando o ETL (TRUNCATE/INSERT)
-- por ser MEMBRO da role intelligence_user (rolinherit = true) — conferido na
-- homolog em 08/09 (has_table_privilege(...,'TRUNCATE') = true).
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f etl/05-owner-intelligence.sql

\set ON_ERROR_STOP on

DO $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT c.relname, c.relkind
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'intelligence'
       AND c.relkind IN ('r', 'p', 'S', 'v', 'm')
       AND c.relowner <> 'intelligence_user'::regrole
  LOOP
    EXECUTE format('ALTER TABLE intelligence.%I OWNER TO intelligence_user', r.relname);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'owner → intelligence_user: % objeto(s) alterado(s)', n;
END $$;

-- Verificação: espera-se só intelligence_user
SELECT pg_get_userbyid(c.relowner) AS owner, c.relkind::text AS tipo, count(*)
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'intelligence' AND c.relkind IN ('r', 'p', 'S', 'v', 'm')
 GROUP BY 1, 2 ORDER BY 1, 2;
