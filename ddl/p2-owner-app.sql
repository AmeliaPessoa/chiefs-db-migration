-- P2/P3 · Owner dos objetos de app.* = app_user
-- (feedback Chiefs 10/09, item 6 — BLOQUEANTE do Rails homolog no banco novo)
--
-- Por quê: o release phase do Heroku (`rails db:migrate`) roda com a role da
-- aplicação (DATABASE_URL = app_user, conferido em 10/09), e 2 das 3
-- migrations pendentes fazem `add_column :chiefs`. ALTER TABLE exige ser
-- OWNER — não é privilégio concedível por GRANT (app_user já tem USAGE+CREATE
-- no schema; criar tabela nova funciona, alterar as 97 movidas no P1 não).
-- Releases v251/v252 (09-10/09) morreram com "must be owner of table chiefs".
--
-- É o MESMO desenho já aplicado em intelligence.* (etl/05-owner-intelligence.sql):
-- a role que roda as migrations do app é dona dos objetos do seu schema
-- (decisão (A) do feedback de 10/09 — ver p2/0. p2-entregas.md). No P1 o
-- CREATE no schema app já previa migrations Rails como app_user (§3 do
-- p1-schemas-roles-grants.sql); o que faltou foi transferir o owner das
-- tabelas MOVIDAS de public → app (§7), que ficaram com a credencial default.
--
-- Executar como a credencial DEFAULT do Heroku (dona atual dos objetos e
-- membro de app_user — ALTER OWNER exige as duas coisas):
--   psql "$(heroku pg:credentials:url DATABASE_URL --name default -a <app> | grep -oE 'postgres://[^ ]+')" \
--        -v ON_ERROR_STOP=1 -f ddl/p2-owner-app.sql
--
-- O que muda / o que NÃO muda:
--   · tabelas, partições, sequences, views e matviews de app → owner app_user;
--     índices e sequences ligadas a coluna (serial/identity) seguem a tabela
--     automaticamente — e SÓ assim (ALTER direto nelas falha; achado do
--     smoke test local em 10/09, vale também para o bloco enviado pelo cliente);
--   · ACLs são PRESERVADAS: o UPDATE por coluna do intelligence_user nas 53
--     colunas de enriquecimento (item 1 de 08/09) e o SELECT em app.* ficam;
--     os privilégios explícitos da default passam a ser "do owner" e ela
--     continua operando (ETL merge, ALTER do enrichment, índices, GRANTs)
--     por ser MEMBRO de app_user (rolinherit);
--   · o SCHEMA app em si continua da default (app_user tem CREATE nele — basta);
--   · default privileges FOR ROLE app_user (SELECT p/ intelligence_user em
--     tabelas novas) já existem desde o P1 e continuam valendo;
--   · as views public.vw_ca_* (owner default) continuam funcionando: a default
--     herda SELECT em app.* via app_user.
-- Idempotente: só toca o que ainda não é do app_user. Reexecutar = no-op.
-- Também é passo do P1 em PRODUÇÃO (após o move de schema): ver
-- p1-schemas-roles-grants.sql §7.7.

\set ON_ERROR_STOP on

-- Pré-checagem: a credencial atual precisa ser membro de app_user
DO $$ BEGIN
  IF NOT pg_has_role(current_user, 'app_user', 'MEMBER') THEN
    RAISE EXCEPTION 'credencial % não é membro de app_user — usar a credencial default do Heroku', current_user;
  END IF;
END $$;

-- Sequences ligadas a coluna (serial/identity, pg_depend deptype 'a'/'i')
-- NÃO aceitam ALTER ... OWNER direto ("cannot change owner of sequence ...
-- linked to table") — elas mudam junto com o ALTER TABLE da tabela dona.
-- Por isso: tabelas primeiro, e só sequences avulsas na lista.
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
  RAISE NOTICE 'owner → app_user: % objeto(s) alterado(s)', n;
END $$;

-- Verificação 1: espera-se só app_user (tabelas, sequences, views) — índices
-- aparecem em 'i' e seguem a tabela
SELECT pg_get_userbyid(c.relowner) AS owner, c.relkind::text AS tipo, count(*)
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'app' AND c.relkind IN ('r', 'p', 'S', 'v', 'm', 'i')
 GROUP BY 1, 2 ORDER BY 1, 2;

-- Verificação 1b: nenhuma sequence ligada ficou com owner diferente da tabela
-- (esperado: 0 linhas; se aparecer, corrigir com ALTER SEQUENCE ... OWNED BY NONE,
--  ALTER TABLE <seq> OWNER TO app_user, ALTER SEQUENCE ... OWNED BY <tabela.coluna>)
SELECT s.relname AS sequence, t.relname AS tabela,
       pg_get_userbyid(s.relowner) AS owner_seq, pg_get_userbyid(t.relowner) AS owner_tabela
  FROM pg_depend d
  JOIN pg_class s ON s.oid = d.objid AND s.relkind = 'S'
  JOIN pg_class t ON t.oid = d.refobjid
  JOIN pg_namespace n ON n.oid = s.relnamespace
 WHERE n.nspname = 'app' AND d.classid = 'pg_class'::regclass
   AND d.refclassid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')
   AND s.relowner <> t.relowner;

-- Verificação 2: grants de cutover preservados (esperado: 53 colunas com
-- UPDATE p/ intelligence_user em app.chiefs; SELECT de tabela mantido)
SELECT 'intelligence_user: colunas com UPDATE em app.chiefs' AS k,
       count(*)::text AS v
  FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'app' AND c.relname = 'chiefs' AND a.attnum > 0
   AND NOT a.attisdropped AND a.attacl::text LIKE '%intelligence_user=w%'
UNION ALL
SELECT 'intelligence_user: SELECT em app.chiefs',
       has_table_privilege('intelligence_user', 'app.chiefs', 'SELECT')::text
UNION ALL
SELECT 'app_user: SELECT em app.schema_migrations',
       has_table_privilege('app_user', 'app.schema_migrations', 'SELECT')::text
UNION ALL
SELECT 'default (' || current_user || '): UPDATE em app.chiefs via membership',
       has_table_privilege(current_user, 'app.chiefs', 'UPDATE')::text;
