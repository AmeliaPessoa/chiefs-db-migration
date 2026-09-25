-- P2/P3 · Índices em app.chiefs para as colunas de enriquecimento
-- (feedback Chiefs 08/09, item 3, lista fechada 24/09 — necessário para produção; opcional no teste)
--
-- Hoje app.chiefs só tem os 5 índices do Rails (pkey, email, slug,
-- reset_password_token, provider+uid). Abaixo, a lista fechada com o cliente
-- em 24/09: 3 B-tree de status + 2 GIN de trigramas para as buscas ILIKE.
-- Ordem no runbook: DEPOIS do `alembic upgrade head` (o índice de
-- all_job_titles depende de função criada por migration do Intelligence).
--
-- CONCURRENTLY: não bloqueia escrita do Rails/enrichment durante a criação;
-- por isso NÃO pode rodar dentro de transação (sem BEGIN; psql -f roda
-- autocommit). Se um CREATE INDEX CONCURRENTLY falhar no meio, ele deixa um
-- índice INVALID: conferir com a query do fim e dropar/recriar.
--
-- Executar como a credencial DEFAULT (owner de app.chiefs):
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/ddl-main-enrichment-indexes.sql

\set ON_ERROR_STOP on

-- ===== 1 · B-tree de status (lista do cliente, 08/09) =====
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_enrichment_status
  ON app.chiefs (enrichment_status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_vectorization_status
  ON app.chiefs (vectorization_status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_needs_re_enrichment
  ON app.chiefs (needs_re_enrichment) WHERE needs_re_enrichment;

-- ===== 2 · GIN de trigramas para as buscas ILIKE (lista fechada 24/09) =====
-- A busca do Intelligence escreve `<expr> ILIKE '%termo%'`; o índice só é
-- usado se a expressão do índice for IDÊNTICA à da consulta e IMMUTABLE.
-- Pré-requisito: pg_trgm em public (CREATE EXTENSION pg_trgm WITH SCHEMA public).
--
-- industries_experience é varchar em app.chiefs: o cast para text é imutável
-- e bate com a consulta atual (industries_experience::text ILIKE).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_industries_experience_trgm
  ON app.chiefs USING gin ((industries_experience::text) public.gin_trgm_ops);

-- all_job_titles é text[]: `all_job_titles::text` (formato do #938 do
-- cliente) NÃO indexa — o cast de array usa array_out, que é STABLE
-- (conferido no fluffy 25/09: "functions in index expression must be marked
-- IMMUTABLE"). Proposta enviada ao Renan em 25/09: função IMMUTABLE
-- criada por migration do Intelligence (definição num lugar só, como
-- compat_csv_split), com o mesmo corpo do cast (contagens idênticas):
--   CREATE OR REPLACE FUNCTION intelligence.compat_array_text(text[]) RETURNS text
--     LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$ SELECT $1::text $$;
-- e a busca passa a escrever intelligence.compat_array_text(all_job_titles) ILIKE '%termo%'.
-- Só cria o índice se a função existir (senão avisa e segue):
SELECT to_regprocedure('intelligence.compat_array_text(text[])') IS NOT NULL AS tem_compat_array_text \gset
\if :tem_compat_array_text
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_all_job_titles_trgm
  ON app.chiefs USING gin (intelligence.compat_array_text(all_job_titles) public.gin_trgm_ops);
\else
\echo 'AVISO: intelligence.compat_array_text(text[]) não existe — índice de all_job_titles NÃO criado (aguarda migration do Intelligence)'
\endif
-- Custo: índice de app.chiefs passa a depender de função do schema
-- intelligence: CREATE OR REPLACE continua possível, DROP FUNCTION falha
-- enquanto o índice existir.

-- ===== Fora da lista (24/09) =====
-- · GIN direto em all_job_titles (operadores de array @>/&&): a busca não usa
--   mais esses operadores desde o #938.
-- · GIN com intelligence.compat_csv_split(col::text) nas 10 colunas CSV
--   (industries_experience, sectors_experience, work_model, business_model,
--   business_moment, main_companies, hard_skills, others_language,
--   availability_status, company_profiles — varchar/text em app.chiefs,
--   varchar[] no Railway) e GIN em sector_experience_detail (jsonb): só se
--   aparecer consulta com @>/&& sobre as views de compat. Modelo:
--   CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_<col>_gin
--     ON app.chiefs USING gin (intelligence.compat_csv_split(<col>::text));

-- ===== Verificação: nenhum índice INVALID em app.chiefs =====
SELECT i.indexrelid::regclass AS indice, i.indisvalid
  FROM pg_index i
 WHERE i.indrelid = 'app.chiefs'::regclass
 ORDER BY 1;
