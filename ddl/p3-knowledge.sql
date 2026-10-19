-- P3 · Schema knowledge (módulo do squad do Duda; pedido do Renan 19/10) —
-- mesmo modelo do analytical (ddl/p3-analytical-tl.sql).
--
-- Desenho:
--   • schema knowledge: owner = credencial default do addon; tl com USAGE + CREATE;
--     DDL versionado em ddl/knowledge/ (repo do Intelligence) aplicado por membro
--     de tl com SET ROLE tl → owner dos objetos = tl.
--   • knowledge_app (credencial de SERVIÇO, não agente — criada antes com
--     heroku pg:credentials:create DATABASE_URL --name knowledge_app -a <app>):
--     USAGE em knowledge; S/I/U nas tabelas e USAGE/SELECT nas sequences que o tl
--     criar (default privileges FOR ROLE tl); sem DELETE/TRUNCATE (trecho antigo
--     sai por versão/soft delete); USAGE em public (vector vive em public nos 2
--     bancos) e heroku_ext (pg_trgm/unaccent); SELECT numa lista FECHADA de views
--     de intelligence (seção 4 — preencher com a lista que vem com o DDL);
--     NENHUM acesso a app; sem CREATE em lugar nenhum.
--   • analytical_reader: SELECT no que o tl criar em knowledge.
--   • Limites na role (seção 5, conectado COMO knowledge_app — a default não
--     altera outra role no Heroku): statement_timeout = 30s e search_path.
--     CONNECTION LIMIT 5 NÃO é possível no Heroku (atributo de role exige
--     CREATEROLE, que a default não tem) → limitar no pool do módulo (max 5) e
--     conferir em pg_stat_activity; a ingestão só roda 01h–06h.
--
-- Ordem: fluffy (smoke) → PINK só com OK por escrito do Renan.
-- Executar como a credencial DEFAULT:
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p3-knowledge.sql
-- Depois, conectado como knowledge_app: a seção 5 (ver fim do arquivo).
-- Idempotente.

\set ON_ERROR_STOP on

BEGIN;

-- 1 · Schema e quem cria
CREATE SCHEMA IF NOT EXISTS knowledge;
GRANT USAGE, CREATE ON SCHEMA knowledge TO tl;
GRANT USAGE ON SCHEMA knowledge TO knowledge_app, analytical_reader;
REVOKE CREATE ON SCHEMA knowledge FROM knowledge_app, analytical_reader, worker, intelligence_user, looker_reader;
REVOKE CREATE ON SCHEMA app, intelligence, analytical, lab, public FROM knowledge_app;

-- 2 · knowledge_app: extensões (vector em public; pg_trgm/unaccent em heroku_ext) e CONNECT
GRANT USAGE ON SCHEMA public, heroku_ext TO knowledge_app;
DO $$ BEGIN EXECUTE format('GRANT CONNECT ON DATABASE %I TO knowledge_app', current_database()); END $$;

-- 3 · O que já existir em knowledge e o que o tl criar daqui em diante
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA knowledge TO knowledge_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA knowledge TO knowledge_app;
GRANT SELECT ON ALL TABLES IN SCHEMA knowledge TO analytical_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE tl IN SCHEMA knowledge GRANT SELECT, INSERT, UPDATE ON TABLES TO knowledge_app;
ALTER DEFAULT PRIVILEGES FOR ROLE tl IN SCHEMA knowledge GRANT USAGE, SELECT ON SEQUENCES TO knowledge_app;
ALTER DEFAULT PRIVILEGES FOR ROLE tl IN SCHEMA knowledge GRANT SELECT ON TABLES TO analytical_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA knowledge GRANT SELECT, INSERT, UPDATE ON TABLES TO knowledge_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA knowledge GRANT USAGE, SELECT ON SEQUENCES TO knowledge_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA knowledge GRANT SELECT ON TABLES TO analytical_reader;

-- 4 · Lista FECHADA de views de intelligence que o knowledge_app lê
--     (a preencher com o DDL do módulo; USAGE em intelligence é necessário para
--     resolver o nome, mas sem GRANT em tabela nenhuma além da lista)
GRANT USAGE ON SCHEMA intelligence TO knowledge_app;
-- GRANT SELECT ON intelligence.<view_1>, intelligence.<view_2> TO knowledge_app;

-- 6 · Verificação
DO $$
DECLARE n int;
BEGIN
  IF NOT has_schema_privilege('tl', 'knowledge', 'CREATE') THEN RAISE EXCEPTION 'tl sem CREATE em knowledge'; END IF;
  IF has_schema_privilege('knowledge_app', 'knowledge', 'CREATE') THEN RAISE EXCEPTION 'knowledge_app com CREATE em knowledge'; END IF;
  IF has_schema_privilege('knowledge_app', 'app', 'USAGE') THEN RAISE EXCEPTION 'knowledge_app com USAGE em app'; END IF;
  IF NOT has_schema_privilege('knowledge_app', 'public', 'USAGE') OR NOT has_schema_privilege('knowledge_app', 'heroku_ext', 'USAGE') THEN RAISE EXCEPTION 'knowledge_app sem USAGE em public/heroku_ext'; END IF;
  SELECT count(*) INTO n FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) a
   WHERE c.relnamespace IN ('app'::regnamespace, 'intelligence'::regnamespace) AND a.grantee = 'knowledge_app'::regrole
     AND NOT (c.relnamespace = 'intelligence'::regnamespace AND c.relkind = 'v' AND a.privilege_type = 'SELECT');
  IF n > 0 THEN RAISE EXCEPTION 'knowledge_app com privilégio fora do desenho em app/intelligence (% objeto(s))', n; END IF;
END $$;

COMMIT;

SELECT r AS role, has_schema_privilege(r, 'knowledge', 'USAGE') AS usage, has_schema_privilege(r, 'knowledge', 'CREATE') AS create
  FROM unnest(ARRAY['tl','knowledge_app','analytical_reader','intelligence_user','worker','looker_reader','app_user']) r;
SELECT pg_get_userbyid(defaclrole) AS criador, defaclobjtype AS tipo, defaclacl
  FROM pg_default_acl WHERE defaclnamespace = 'knowledge'::regnamespace ORDER BY 1, 2;

-- 5 · Limites na role — rodar CONECTADO COMO knowledge_app (psql "$(url knowledge_app)"):
--   DO $$ BEGIN
--     EXECUTE format('ALTER ROLE %I IN DATABASE %I SET search_path = knowledge, intelligence, public, heroku_ext', current_user, current_database());
--     EXECUTE format('ALTER ROLE %I IN DATABASE %I SET statement_timeout = ''30s''', current_user, current_database());
--   END $$;
--   SELECT r.rolname, s.setconfig FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole WHERE r.rolname = current_user;
