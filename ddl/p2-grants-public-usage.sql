-- P2/P3 · USAGE no schema public para as roles least-privilege
-- (feedback Chiefs 10/09, item 7 — quebra silenciosa em runtime)
--
-- pg_trgm (similarity) e vector estão instalados em `public`; unaccent em
-- `heroku_ext`. O P1 revogou tudo de PUBLIC no schema public (item 16) e só
-- devolveu USAGE ao intelligence_user. Sem USAGE, o Postgres simplesmente
-- REMOVE `public` do search_path efetivo, sem erro de permissão — o sintoma
-- é "function similarity(...) does not exist" (o Rails usa similarity() +
-- unaccent() no job de alerta de chief duplicado; schema.rb declara
-- enable_extension "pg_trgm"). Mesma armadilha do Achado #2 de 20/08
-- (heroku_ext), agora em public.
--
-- Escopo: USAGE (enxergar objetos/funções). CREATE em public continua
-- revogado. looker_reader/analytical_reader ganham USAGE em public e em
-- heroku_ext pelo mesmo motivo (funções de extensão em consultas
-- analíticas); NÃO ganham nada em app/intelligence — escopo delas segue
-- sendo SELECT em `analytical` (P1 §5), a revisar na árvore de permissões.
--
-- Executar como a credencial DEFAULT (owner do schema public no Heroku):
--   psql "$(heroku pg:credentials:url DATABASE_URL --name default -a <app> | grep -oE 'postgres://[^ ]+')" \
--        -v ON_ERROR_STOP=1 -f ddl/p2-grants-public-usage.sql
-- Idempotente (GRANT repetido é no-op). Também incorporado ao P1
-- (p1-schemas-roles-grants.sql §7.6) para produção.

\set ON_ERROR_STOP on

GRANT USAGE ON SCHEMA public     TO app_user, intelligence_user, looker_reader, analytical_reader;
GRANT USAGE ON SCHEMA heroku_ext TO app_user, intelligence_user, looker_reader, analytical_reader;

-- Verificação: tudo true; CREATE em public continua false para as 4 roles
SELECT r AS role,
       has_schema_privilege(r, 'public', 'USAGE')     AS public_usage,
       has_schema_privilege(r, 'public', 'CREATE')    AS public_create,
       has_schema_privilege(r, 'heroku_ext', 'USAGE') AS heroku_ext_usage
  FROM unnest(ARRAY['app_user', 'intelligence_user', 'looker_reader', 'analytical_reader']) r;

-- Prova funcional (não depende de search_path): as funções resolvem no
-- schema em que a extensão está. Em produção pg_trgm e unaccent vivem em
-- heroku_ext e vector em public (ensaio 06/10); na homolog pg_trgm está em
-- public — por isso o schema é lido de pg_extension, não fixado.
SELECT extname, extversion, extnamespace::regnamespace AS schema
  FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent', 'vector') ORDER BY 1;
DO $$
DECLARE s_trgm text; s_unacc text; sim real; una text;
BEGIN
  SELECT n.nspname INTO s_trgm  FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'pg_trgm';
  SELECT n.nspname INTO s_unacc FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'unaccent';
  IF s_trgm IS NULL THEN RAISE EXCEPTION 'pg_trgm não instalada'; END IF;
  EXECUTE format('SELECT %I.similarity(%L, %L)', s_trgm, 'chiefs', 'chief') INTO sim;
  IF s_unacc IS NOT NULL THEN
    EXECUTE format('SELECT %I.unaccent(%L)', s_unacc, 'ação') INTO una;
  END IF;
  RAISE NOTICE 'similarity ok (%.%) = %; unaccent (%) = %', s_trgm, 'similarity', sim, coalesce(s_unacc, 'ausente'), coalesce(una, '-');
END $$;
