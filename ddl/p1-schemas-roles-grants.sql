-- P1 · Schemas, grants e default privileges
-- Executar conectado como a credencial DEFAULT do Heroku PG (dona dos objetos):
--   heroku pg:psql -a $APP < p1/01-schemas-roles-grants.sql
-- Pré-requisito: as 4 roles já criadas via `heroku pg:credentials:create`
-- (app_user, intelligence_user, looker_reader, analytical_reader).

\set ON_ERROR_STOP on

BEGIN;

-- ============================================================
-- 1 · Schemas (checklist item 2)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS intelligence;
CREATE SCHEMA IF NOT EXISTS analytical;
CREATE SCHEMA IF NOT EXISTS lab;  -- governança [A CONFIRMAR no kickoff]

-- ============================================================
-- 2 · Higiene do schema public (checklist item 16)
-- ============================================================
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
DO $$ BEGIN
  EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database());
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_user, intelligence_user, looker_reader, analytical_reader',
                 current_database());
END $$;

-- ============================================================
-- 3 · app_user — CRUD restrito a app (itens 4, 5, 6)
--     CREATE no schema é necessário para migrações Rails; e as tabelas
--     existentes precisam ter app_user como OWNER (§7.7) — migration com
--     ALTER TABLE exige ownership.
-- ============================================================
GRANT USAGE, CREATE ON SCHEMA app TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT USAGE, SELECT ON SEQUENCES TO app_user;
-- NENHUM grant em intelligence, analytical ou lab.

-- ============================================================
-- 4 · intelligence_user — dono do domínio de IA + leitura de app
--     (itens 7, 8, 9)
-- ============================================================
GRANT USAGE, CREATE ON SCHEMA intelligence TO intelligence_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA intelligence TO intelligence_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA intelligence TO intelligence_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA intelligence
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO intelligence_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA intelligence
  GRANT USAGE, SELECT ON SEQUENCES TO intelligence_user;

-- SELECT-only em app (para alimentar as derivadas):
GRANT USAGE ON SCHEMA app TO intelligence_user;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO intelligence_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT SELECT ON TABLES TO intelligence_user;
-- Tabelas futuras criadas pelas MIGRAÇÕES RAILS (owner = app_user) também
-- precisam nascer legíveis pela inteligência:
ALTER DEFAULT PRIVILEGES FOR ROLE app_user IN SCHEMA app
  GRANT SELECT ON TABLES TO intelligence_user;
-- (a credencial default é membro das credenciais criadas via pg:credentials,
--  por isso o FOR ROLE funciona; se der "permission denied", rodar como app_user)

-- ============================================================
-- 5 · looker_reader + analytical_reader — SELECT-only em analytical
--     (itens 10, 11, 12)  — ALTER DEFAULT PRIVILEGES NÃO é opcional
-- ============================================================
GRANT USAGE ON SCHEMA analytical TO looker_reader, analytical_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA analytical TO looker_reader, analytical_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytical
  GRANT SELECT ON TABLES TO looker_reader, analytical_reader;
-- P2: quando a replicação/ETL criar tabelas com OUTRA role, repetir com
-- ALTER DEFAULT PRIVILEGES FOR ROLE <role-criadora> IN SCHEMA analytical ...

-- ============================================================
-- 6 · lab — proposta pendente de kickoff (item 13):
--     gravável pela inteligência, invisível para app e BI
-- ============================================================
GRANT USAGE, CREATE ON SCHEMA lab TO intelligence_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA lab
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO intelligence_user;
-- NENHUM grant para app_user, looker_reader ou analytical_reader.

COMMIT;

-- ============================================================
-- 7 · D-12: mover as tabelas do Rails de public para app
--     Rodar DENTRO DA JANELA, antes de reapontar o Rails.
--     Sequences owned acompanham a tabela automaticamente.
-- ============================================================
BEGIN;
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I SET SCHEMA app', r.tablename);
  END LOOP;
END $$;
-- conferir se sobrou view/matview/sequence órfã em public:
SELECT 'VIEW' tipo, viewname nome FROM pg_views WHERE schemaname='public'
UNION ALL
SELECT 'MATVIEW', matviewname FROM pg_matviews WHERE schemaname='public'
UNION ALL
SELECT 'SEQUENCE', sequencename FROM pg_sequences WHERE schemaname='public';

-- 7.5 · RE-APLICAR grants de tabela após o move — OBRIGATÓRIO.
--       Os "GRANT ... ON ALL TABLES" da seção 3 rodaram com o schema app
--       ainda VAZIO, e tabela MOVIDA não herda default privileges
--       (constatado na homolog em 19/08/2026: release v246 falhou com
--       "permission denied for table schema_migrations").
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO intelligence_user;

-- 7.6 · Extensões do Heroku (Achado #2 do feedback de 20/08): o Heroku
--       instala extensões novas no schema heroku_ext; sem USAGE os roles
--       least-privilege não enxergam funções como unaccent() (quebrou o
--       duplicate_chief_alert_job na homolog). Conferir SEMPRE:
--       pg_extension × search_path × USAGE de todos os roles novos.
GRANT USAGE ON SCHEMA heroku_ext TO app_user, intelligence_user, looker_reader, analytical_reader;
--       Idem para `public` (feedback 10/09, item 7): pg_trgm e vector ficam
--       em public e o item 16 revogou tudo de PUBLIC — sem USAGE o
--       search_path descarta o schema em silêncio ("function similarity(...)
--       does not exist" no Rails). USAGE apenas; CREATE segue revogado.
GRANT USAGE ON SCHEMA public TO app_user, intelligence_user, looker_reader, analytical_reader;

-- 7.7 · OWNER das tabelas movidas → app_user (feedback 10/09, item 6 —
--       decisão (A)). O `rails db:migrate` do release phase roda como
--       app_user (DATABASE_URL) e ALTER TABLE exige ser OWNER, que não é
--       concedível por GRANT. O move (7) mantém o owner na default → a
--       primeira migration com add_column falha ("must be owner of table
--       chiefs", homolog v251, 09/09). Mesmo desenho de intelligence.* =
--       intelligence_user. ACLs (inclusive grants por coluna) são
--       preservadas; a default segue operando por ser membro de app_user.
--       Sequences ligadas a coluna (serial/identity, pg_depend deptype 'a'/'i')
--       NÃO aceitam ALTER ... OWNER direto ("cannot change owner of sequence ...
--       linked to table") — elas mudam junto com o ALTER TABLE da tabela dona.
--       Por isso: tabelas primeiro, e só sequences avulsas na lista.
DO $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT c.relname, c.relkind
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'app'
       AND c.relkind IN ('r', 'p', 'S', 'v', 'm')
       AND c.relowner <> 'app_user'::regrole
       AND NOT (c.relkind = 'S' AND EXISTS (              -- sequence ligada a coluna: segue a tabela
             SELECT 1 FROM pg_depend d
              WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid
                AND d.refclassid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')))
     ORDER BY (c.relkind = 'S'), c.relname                 -- tabelas/views antes das sequences avulsas
  LOOP
    EXECUTE format('ALTER TABLE app.%I OWNER TO app_user', r.relname);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'owner app.* → app_user: % objeto(s)', n;
END $$;
COMMIT;

-- ============================================================
-- 8 · search_path da aplicação (item 17) — sem mudança de código
--     ⚠ Na homolog (19/08) a credencial default NÃO pôde alterar a role
--     ("permission denied to alter role"): rodar este bloco conectado
--     como o PRÓPRIO app_user (role altera as próprias configs):
--       psql "$(heroku pg:credentials:url <addon> --name app_user -a $APP | grep -oE 'postgres://[^ ]+')"
-- ============================================================
DO $$ BEGIN
  EXECUTE format('ALTER ROLE app_user IN DATABASE %I SET search_path = app, public, heroku_ext',
                 current_database());
END $$;

-- Verificação rápida (itens 2 e 3):
SELECT nspname FROM pg_namespace WHERE nspname IN ('app','intelligence','analytical','lab');
SELECT rolname, rolcanlogin FROM pg_roles
 WHERE rolname IN ('app_user','intelligence_user','looker_reader','analytical_reader');
