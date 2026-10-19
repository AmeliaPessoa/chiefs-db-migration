-- P3 · Braço Industry da busca híbrida: índice que a VIEW consegue usar
-- (EXPLAIN pedido pelo Renan 19/10; medido na homolog 19/10: Seq Scan, 64 ms)
--
-- A view intelligence.chiefs_ativos expõe
--   industries_experience = intelligence.compat_csv_split(app.chiefs.industries_experience::text)   (text[])
-- e o braço Industry (src/search/hybrid_search.py::_run_industry_arm) escreve
--   c.industries_experience::text ILIKE '%termo%'
-- → no plano isso vira  (compat_csv_split(industries_experience::text))::text ~~* ...
--   O cast text[] → text usa array_out, que é STABLE: NÃO indexável. Por isso o
--   idx_chiefs_industries_text_trgm ((industries_experience::text) gin_trgm_ops),
--   criado na janela, nunca é usado por essa consulta — ele indexa o cast da
--   COLUNA BASE, que a view não expõe.
--
-- Solução em duas partes (a mesma da migration 115 para all_job_titles):
--   1) índice de expressão com a função IMMUTABLE compat_array_text (mig 115)
--      aplicada à MESMA expressão da view:
--        gin (intelligence.compat_array_text(intelligence.compat_csv_split(industries_experience::text)) gin_trgm_ops)
--   2) o braço Industry passa a escrever
--        intelligence.compat_array_text(c.industries_experience) ILIKE '%termo%'
--      (c.industries_experience já é o text[] da view) — card da Chiefs.
--   Sem (2) o índice não é usado; sem (1) a reescrita não ajuda.
--   Depois de (1)+(2) validados em PROD: DROP INDEX CONCURRENTLY idx_chiefs_industries_text_trgm (640 kB, inútil).
--
-- Pré-requisitos: compat_csv_split e compat_array_text IMMUTABLE (mig 107/115);
-- pg_trgm (schema lido de pg_extension). Executar como a credencial DEFAULT
-- (owner app_user via membership + USAGE em intelligence), banco vivo, CONCURRENTLY:
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p3-indice-industry-view.sql
-- Validação (como intelligence_user, search_path da role):
--   EXPLAIN (ANALYZE, BUFFERS) SELECT c.id FROM chiefs_ativos c WHERE c.is_deleted = false
--     AND (intelligence.compat_array_text(c.industries_experience) ILIKE '%Fintech%'
--          OR intelligence.compat_array_text(c.industries_experience) ILIKE '%Serviços Financeiros%') LIMIT 100;
--   → esperado "Bitmap Index Scan on idx_app_chiefs_industries_compat_trgm".

\set ON_ERROR_STOP on

SELECT n.nspname AS trgm_schema FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'pg_trgm' \gset
\if :{?trgm_schema}
\else
\echo 'ERRO: pg_trgm não instalada'
\q
\endif
SELECT (to_regprocedure('intelligence.compat_array_text(text[])') IS NOT NULL
        AND to_regprocedure('intelligence.compat_csv_split(text)') IS NOT NULL) AS tem_funcoes \gset
\if :tem_funcoes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_app_chiefs_industries_compat_trgm
  ON app.chiefs USING gin (intelligence.compat_array_text(intelligence.compat_csv_split(industries_experience::text)) :"trgm_schema".gin_trgm_ops);
\else
\echo 'ERRO: compat_array_text(text[]) / compat_csv_split(text) não existem em intelligence (migrations 107/115)'
\q
\endif

SELECT i.indexrelid::regclass AS indice, i.indisvalid, pg_size_pretty(pg_relation_size(i.indexrelid)) AS tamanho
  FROM pg_index i WHERE i.indrelid = 'app.chiefs'::regclass AND i.indexrelid::regclass::text ILIKE '%industr%' ORDER BY 1;
