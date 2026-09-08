-- P2/P3 · Índices em app.chiefs para as colunas de enriquecimento
-- (feedback Chiefs 08/09, item 3 — necessário para produção; opcional no teste)
--
-- Hoje app.chiefs só tem os 5 índices do Rails (pkey, email, slug,
-- reset_password_token, provider+uid). Abaixo, o MÍNIMO pedido pelo cliente.
--
-- CONCURRENTLY: não bloqueia escrita do Rails/enrichment durante a criação;
-- por isso NÃO pode rodar dentro de transação (sem BEGIN; psql -f roda
-- autocommit). Se um CREATE INDEX CONCURRENTLY falhar no meio, ele deixa um
-- índice INVALID: conferir com a query do fim e dropar/recriar.
--
-- Executar como a credencial DEFAULT (owner de app.chiefs):
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/ddl-main-enrichment-indexes.sql

\set ON_ERROR_STOP on

-- ===== 1 · Mínimo para produção (lista do cliente, 08/09) =====
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_all_job_titles_gin
  ON app.chiefs USING gin (all_job_titles);                          -- text[] (tipo da origem)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_enrichment_status
  ON app.chiefs (enrichment_status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_vectorization_status
  ON app.chiefs (vectorization_status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_needs_re_enrichment
  ON app.chiefs (needs_re_enrichment) WHERE needs_re_enrichment;

-- ===== 2 · Demais GIN do Railway — AGUARDANDO LISTA FINAL do cliente =====
-- Achado (08/09, conferido na homolog): as 10 colunas industries_experience,
-- sectors_experience, work_model, business_model, business_moment,
-- main_companies, hard_skills, others_language, availability_status e
-- company_profiles são `character varying`/`text` (CSV) em app.chiefs — no
-- Railway (chiefs_ativos) são `character varying[]`. Um GIN direto na coluna
-- NÃO compila (varchar não tem opclass GIN padrão; e o app consulta como
-- array). As views de compatibilidade da migration 107 (chiefs_ativos /
-- chiefs_todos) já convertem com intelligence.compat_csv_split(col::text),
-- que é IMMUTABLE → o equivalente correto é um índice de EXPRESSÃO com a
-- mesma chamada, que o planner casa quando a view é inlined (`@>`, `&&`).
-- Custo: cria dependência app.chiefs → função no schema intelligence: a
-- função pode ser CREATE OR REPLACE, mas um DROP FUNCTION passa a falhar
-- enquanto os índices existirem (a migration precisa saber disso).
-- Descomentar após a validação do cliente durante o teste:
--
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_industries_experience_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(industries_experience::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_sectors_experience_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(sectors_experience::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_work_model_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(work_model::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_business_model_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(business_model::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_business_moment_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(business_moment::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_main_companies_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(main_companies::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_hard_skills_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(hard_skills));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_others_language_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(others_language::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_availability_status_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(availability_status::text));
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_company_profiles_gin
--   ON app.chiefs USING gin (intelligence.compat_csv_split(company_profiles::text));
-- (sector_experience_detail é jsonb em app.chiefs — GIN direto funciona:)
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_sector_experience_detail_gin
--   ON app.chiefs USING gin (sector_experience_detail);

-- ===== Verificação: nenhum índice INVALID em app.chiefs =====
SELECT i.indexrelid::regclass AS indice, i.indisvalid
  FROM pg_index i
 WHERE i.indrelid = 'app.chiefs'::regclass
 ORDER BY 1;
