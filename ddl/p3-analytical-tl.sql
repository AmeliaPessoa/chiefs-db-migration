-- P3 · Schema analytical: quem cria e quem lê (pedido do Renan 15/10)
--
-- Decisão proposta (Amelia, 17/10): o DDL das tabelas de analytical fica
-- versionado no repositório do Intelligence (ddl/analytical/) e é APLICADO
-- PELO TL (rubi/roma, membros do grupo tl), que passa a ser OWNER dos objetos.
-- Motivos: (1) regra (A) de 10/09 — quem roda o DDL é dono; (2) a Chiefs opera
-- sozinha depois do encerramento, sem depender da credencial default nem da
-- prestadora; (3) o intelligence_user NÃO ganha CREATE em analytical (seria
-- DDL de preDeploy num schema que o Looker lê — concordo com a Chiefs).
--
-- Como os membros de tl herdam os privilégios do grupo (INHERIT TRUE), rubi ou
-- roma criam a tabela com "SET ROLE tl" ou simplesmente como membro: o owner
-- fica em tl se o CREATE for feito com SET ROLE tl (recomendado, para o owner
-- não ser uma pessoa). Default privileges FOR ROLE tl garantem que toda tabela
-- nova em analytical nasça legível/escrevível por quem precisa, sem grant à mão.
--
-- Executar como a credencial DEFAULT (owner do schema analytical), em HML e PROD:
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p3-analytical-tl.sql
-- Idempotente.

\set ON_ERROR_STOP on

BEGIN;

-- 1 · tl cria em analytical; intelligence_user, analytical_reader e looker_reader só usam
GRANT USAGE, CREATE ON SCHEMA analytical TO tl;
GRANT USAGE ON SCHEMA analytical TO intelligence_user, analytical_reader, looker_reader;
REVOKE CREATE ON SCHEMA analytical FROM intelligence_user, worker, analytical_reader, looker_reader;

-- 2 · O que já existir (hoje: 0 objetos) e o que o tl criar daqui em diante
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA analytical TO intelligence_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA analytical TO intelligence_user;
GRANT SELECT ON ALL TABLES IN SCHEMA analytical TO analytical_reader, looker_reader;

ALTER DEFAULT PRIVILEGES FOR ROLE tl IN SCHEMA analytical
  GRANT SELECT, INSERT, UPDATE ON TABLES TO intelligence_user;
ALTER DEFAULT PRIVILEGES FOR ROLE tl IN SCHEMA analytical
  GRANT USAGE, SELECT ON SEQUENCES TO intelligence_user;
ALTER DEFAULT PRIVILEGES FOR ROLE tl IN SCHEMA analytical
  GRANT SELECT ON TABLES TO analytical_reader, looker_reader;
-- Se a Amelia (default) criar algo em analytical durante o engajamento, os
-- default privileges do P1 (seção 5) já cobrem os readers; cobrir também o
-- intelligence_user:
ALTER DEFAULT PRIVILEGES IN SCHEMA analytical
  GRANT SELECT, INSERT, UPDATE ON TABLES TO intelligence_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytical
  GRANT USAGE, SELECT ON SEQUENCES TO intelligence_user;

-- 3 · Verificação
DO $$
BEGIN
  IF NOT has_schema_privilege('tl', 'analytical', 'CREATE') THEN RAISE EXCEPTION 'tl sem CREATE em analytical'; END IF;
  IF has_schema_privilege('intelligence_user', 'analytical', 'CREATE') THEN RAISE EXCEPTION 'intelligence_user com CREATE em analytical'; END IF;
  IF NOT has_schema_privilege('intelligence_user', 'analytical', 'USAGE') THEN RAISE EXCEPTION 'intelligence_user sem USAGE em analytical'; END IF;
  IF NOT has_schema_privilege('looker_reader', 'analytical', 'USAGE') OR NOT has_schema_privilege('analytical_reader', 'analytical', 'USAGE') THEN RAISE EXCEPTION 'readers sem USAGE em analytical'; END IF;
END $$;

COMMIT;

SELECT r AS role, has_schema_privilege(r, 'analytical', 'USAGE') AS usage, has_schema_privilege(r, 'analytical', 'CREATE') AS create
  FROM unnest(ARRAY['tl','worker','intelligence_user','analytical_reader','looker_reader','app_user']) r;
SELECT pg_get_userbyid(defaclrole) AS criador, defaclobjtype AS tipo, defaclacl
  FROM pg_default_acl WHERE defaclnamespace = 'analytical'::regnamespace ORDER BY 1, 2;
