-- P2/P3 · Roles de grupo (tl, worker, reader) e usuários por agente
-- (item 10 de 10/09 — árvore de permissões; mapas do Renan 16/09 e do Bruno 21/09;
--  decisão Amelia 23/09: dar o acesso pedido nos mapas, e o reader É o
--  analytical_reader ampliado para SELECT em app + intelligence)
--
-- Grupo              | membros                     | app     | intelligence                         | analytical
-- -------------------+-----------------------------+---------+--------------------------------------+-----------
-- tl                 | rubi, roma                  | SELECT  | SELECT + INSERT/UPDATE em 7 tabelas  | SELECT
-- worker  (homolog)  | jade, safira, tokyo, bogota | SELECT  | SELECT + INSERT/UPDATE em 11 tabelas | —
--                    |                             |         |   (pipeline_runs só INSERT)          |
-- worker  (produção) | idem                        | SELECT  | SELECT                               | —
-- analytical_reader  | ametista, oslo (+ MCP)      | SELECT  | SELECT                               | SELECT
--
-- Para todos: USAGE em public/heroku_ext; nenhum DELETE/TRUNCATE; nenhum
-- CREATE em schema nenhum; nenhum DDL (não são owner de nada).
--
-- Pré-requisito (Heroku; a default não tem CREATEROLE):
--   for r in tl worker rubi jade safira ametista roma tokyo bogota oslo; do
--     heroku pg:credentials:create DATABASE_URL --name $r -a <app>; done
--   As credenciais-grupo (tl, worker) NUNCA são entregues a ninguém:
--   servem só de grupo. Sem CREATEROLE não dá para torná-las NOLOGIN.
--
-- Executar conectado como a credencial DEFAULT (membro de app_user e
-- intelligence_user, os owners — os GRANTs são feitos "como" o owner):
--   psql "<url-default>" -v ON_ERROR_STOP=1 -v ambiente=homolog  -f ddl/p2-roles-agentes.sql
--   psql "<url-default>" -v ON_ERROR_STOP=1 -v ambiente=producao -f ddl/p2-roles-agentes.sql
-- Depois: ddl/p2-search-path-agentes.sql conectado como CADA usuário, e
-- scripts/testa-permissoes-agentes.sh.
--
-- Idempotente. Em produção, o bloco de escrita do worker é revogado
-- explicitamente (re-rodar com ambiente=producao garante o estado restrito).
--
-- ⚠ A TESTAR na primeira execução em homolog: GRANT de membership (seção 6)
--   exige ADMIN OPTION sobre o grupo (PG 16+). Se a default não tiver,
--   o erro é "permission denied to grant role" — nesse caso, plano B:
--   aplicar os grants das seções 2–5 direto em cada usuário.
--
-- Tabela nova em intelligence que precise de escrita de tl/worker NÃO herda
-- a escrita (default privileges só dão SELECT) — incluir aqui e re-rodar.

\set ON_ERROR_STOP on

\if :{?ambiente}
\else
  DO $$ BEGIN RAISE EXCEPTION 'passe -v ambiente=homolog ou -v ambiente=producao'; END $$;
\endif
SELECT (:'ambiente' IN ('homolog', 'producao')) AS ambiente_valido,
       (:'ambiente' = 'homolog')                AS worker_escreve \gset
\if :ambiente_valido
\else
  DO $$ BEGIN RAISE EXCEPTION 'passe -v ambiente=homolog ou -v ambiente=producao'; END $$;
\endif

BEGIN;

-- ============================================================
-- 1 · Guard-rails comuns (idempotentes, valem nos dois ambientes)
-- ============================================================
GRANT USAGE ON SCHEMA public, heroku_ext TO tl, worker, analytical_reader;
GRANT USAGE ON SCHEMA app, intelligence   TO tl, worker, analytical_reader;
GRANT USAGE ON SCHEMA analytical          TO tl, analytical_reader;

REVOKE CREATE ON SCHEMA app, intelligence, analytical, lab, public FROM tl, worker, analytical_reader;
REVOKE DELETE, TRUNCATE ON ALL TABLES IN SCHEMA app, intelligence FROM tl, worker, analytical_reader;

-- ============================================================
-- 2 · Leitura
-- ============================================================
GRANT SELECT ON ALL TABLES IN SCHEMA app          TO tl, worker, analytical_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA intelligence TO tl, worker, analytical_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA analytical   TO tl, analytical_reader;

-- Tabela/view nova criada por migration (db:migrate como app_user; alembic
-- como intelligence_user) nasce legível pelos grupos:
ALTER DEFAULT PRIVILEGES FOR ROLE app_user IN SCHEMA app
  GRANT SELECT ON TABLES TO tl, worker, analytical_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE intelligence_user IN SCHEMA intelligence
  GRANT SELECT ON TABLES TO tl, worker, analytical_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytical
  GRANT SELECT ON TABLES TO tl, analytical_reader;

-- ============================================================
-- 3 · tl — correção de dado autorizada (homolog = produção)
-- ============================================================
GRANT INSERT, UPDATE ON
  intelligence.jd_chief_stages,
  intelligence.jd_results,
  intelligence.chief_laudo,
  intelligence.chief_laudo_modal_state,
  intelligence.system_prompts,
  intelligence.ui_access_grant,
  intelligence.platform_sync_state
TO tl;

-- ============================================================
-- 4 · worker — escrita só em homolog
-- ============================================================
\if :worker_escreve
GRANT INSERT, UPDATE ON
  intelligence.job_descriptions,
  intelligence.jd_results,
  intelligence.jd_chief_stages,
  intelligence.chief_laudo,
  intelligence.chief_laudo_modal_state,
  intelligence.chief_improvement_event,
  intelligence.chief_stimulus_event,
  intelligence.jd_list_quality,
  intelligence.ui_access_grant,
  intelligence.system_prompts
TO worker;
GRANT INSERT ON intelligence.pipeline_runs TO worker;          -- append-only
REVOKE UPDATE ON intelligence.pipeline_runs FROM worker;
\else
REVOKE INSERT, UPDATE ON ALL TABLES IN SCHEMA intelligence FROM worker;
REVOKE INSERT, UPDATE ON ALL TABLES IN SCHEMA app          FROM worker;
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA intelligence       FROM worker;
\endif

-- ============================================================
-- 5 · Sequences das tabelas com INSERT (serial/identity): USAGE
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT DISTINCT s.oid::regclass AS seq, g.grantee
      FROM (VALUES ('tl'), ('worker')) AS g(grantee)
      JOIN pg_class t
        ON t.relnamespace = 'intelligence'::regnamespace AND t.relkind IN ('r', 'p')
       AND has_table_privilege(g.grantee, t.oid, 'INSERT')
      JOIN pg_depend d
        ON d.refobjid = t.oid AND d.refclassid = 'pg_class'::regclass
       AND d.classid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')
      JOIN pg_class s ON s.oid = d.objid AND s.relkind = 'S'
  LOOP
    EXECUTE format('GRANT USAGE ON SEQUENCE %s TO %I', r.seq, r.grantee);
  END LOOP;
END $$;

-- ============================================================
-- 6 · Membership (um usuário por agente)
-- ============================================================
GRANT tl                TO rubi, roma                  WITH INHERIT TRUE, SET FALSE;
GRANT worker            TO jade, safira, tokyo, bogota WITH INHERIT TRUE, SET FALSE;
GRANT analytical_reader TO ametista, oslo              WITH INHERIT TRUE, SET FALSE;

COMMIT;

-- ============================================================
-- Verificação (evidência em evidencias/feedback-2026-09-22/)
-- ============================================================

-- 1. Membership: esperado 8 linhas
SELECT g.rolname AS grupo, u.rolname AS usuario, m.inherit_option, m.set_option
  FROM pg_auth_members m
  JOIN pg_roles g ON g.oid = m.roleid
  JOIN pg_roles u ON u.oid = m.member
 WHERE g.rolname IN ('tl', 'worker', 'analytical_reader')
   AND u.rolname IN ('rubi','jade','safira','ametista','roma','tokyo','bogota','oslo')
 ORDER BY 1, 2;

-- 2. Escrita por grupo (homolog: tl 7×2, worker 10×2 + 1; produção: tl 7×2, worker 0)
--    (aclexplode e não information_schema: este só mostra roles de que a
--     sessão é membro)
SELECT a.grantee::regrole AS grupo, c.oid::regclass AS tabela,
       string_agg(a.privilege_type, ', ' ORDER BY a.privilege_type) AS privs
  FROM pg_class c
  CROSS JOIN LATERAL aclexplode(c.relacl) a
 WHERE c.relnamespace IN ('app'::regnamespace, 'intelligence'::regnamespace)
   AND a.grantee IN ('tl'::regrole, 'worker'::regrole, 'analytical_reader'::regrole)
   AND a.privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
 GROUP BY 1, 2 ORDER BY 1, 2;

-- 3. CREATE em schema: esperado tudo false
SELECT r AS role, s AS schema, has_schema_privilege(r, s, 'CREATE') AS create
  FROM unnest(ARRAY['tl','worker','analytical_reader']) r,
       unnest(ARRAY['app','intelligence','analytical','lab','public']) s
 WHERE has_schema_privilege(r, s, 'CREATE');
